#!/usr/bin/env bash
# Build balenaOS for the Seeed reComputer RK3588 DevKit.
#
# All Yocto output, downloads and shared-state cache are kept in paths derived
# from this repository. Nothing is written to another clone.
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly MACHINE="recomputer-rk3588-devkit"

BUILD_DIR="build-recomputer-rk3588-devkit"
CLEAN_BUILD=0

usage() {
	cat <<'EOF'
Usage: scripts/build-recomputer-rk3588-devkit.sh [--clean] [--continue] [--development-image] [--disable-kernel-headers] [--build-dir DIR]

Builds balena-image-flasher for recomputer-rk3588-devkit.

  --clean                  remove the selected build directory before building
  --continue               continue as much as possible after a task failure
  --development-image      enable Balena development mode (serial login and
                           development features) for this build
  --disable-kernel-headers skip the kernel-headers-test build dependency.  It
                           pulls a base image from Docker Hub and fails when
                           the registry is unreachable (broken proxy node).
                           Image contents are unaffected; drop the flag when
                           Docker Hub is reachable again.
  --build-dir DIR          repository-relative build directory name (default:
                           build-recomputer-rk3588-devkit)

After a successful build the flashable artifacts are copied (without
timestamp suffixes) to output/images/: the flasher image, the runtime image,
rkspi_loader.img and spl_loader_maskrom.bin.  The full build console log is
written live to output/logs/build-<timestamp>.log (output/logs/latest.log
always points at the newest one).

The build directory contains tmp/, downloads/ and sstate-cache/.  They are
local build artifacts and are excluded from Git.
EOF
}

CONTINUE_BUILD=0
DEVELOPMENT_IMAGE=0
DISABLE_KERNEL_HEADERS=0
while (($#)); do
	case "$1" in
		--clean)
			CLEAN_BUILD=1
			;;
		--build-dir)
			shift
			[[ $# -gt 0 ]] || { echo "--build-dir requires a value" >&2; exit 2; }
			BUILD_DIR="$1"
			;;
		--help|-h)
			usage
			exit 0
			;;
		--continue|-k)
			CONTINUE_BUILD=1
			;;
		--development-image)
			DEVELOPMENT_IMAGE=1
			;;
		--disable-kernel-headers)
			DISABLE_KERNEL_HEADERS=1
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 2
			;;
	esac
	shift
done

if [[ -z "$BUILD_DIR" || "$BUILD_DIR" == /* || "$BUILD_DIR" == */* ||
	"$BUILD_DIR" == *[[:space:]]* || "$BUILD_DIR" == "." || "$BUILD_DIR" == ".." ||
	"$BUILD_DIR" == *".."* ]]; then
	echo "--build-dir must be a safe, repository-relative directory name (without '/')" >&2
	exit 2
fi

for command in git jq node npm python3 docker iptables; do
	command -v "$command" >/dev/null 2>&1 || {
		echo "Missing required host command: $command" >&2
		exit 1
	}
done

cd "$REPO_ROOT"

# chrpath is required by the host sanity checks on some distributions. Keep a
# downloaded copy in a repository-relative, ignored directory when it is not
# installed system-wide; this avoids a hard-coded path from another machine.
if ! command -v chrpath >/dev/null 2>&1; then
	TOOLS_DIR="${REPO_ROOT}/.build-tools"
	CHRPATH_BIN="${TOOLS_DIR}/usr/bin/chrpath"
	if [[ ! -x "$CHRPATH_BIN" ]]; then
		command -v apt-get >/dev/null 2>&1 || {
			echo "Missing host command: chrpath (and apt-get is unavailable to download it)" >&2
			exit 1
		}
		mkdir -p "${TOOLS_DIR}/downloads"
		(
			cd "${TOOLS_DIR}/downloads"
			apt-get download chrpath
			DEB="$(find . -maxdepth 1 -type f -name 'chrpath_*.deb' -print -quit)"
			[[ -n "$DEB" ]] || { echo "apt-get did not download chrpath" >&2; exit 1; }
			dpkg-deb -x "$DEB" "$TOOLS_DIR"
		)
	fi
	export PATH="${TOOLS_DIR}/usr/bin:${PATH}"
fi

# Build environments commonly lack the locale expected by BitBake. Generate
# it below the repository when needed and expose it only for this invocation.
if ! locale -a 2>/dev/null | grep -qi '^en_US\.utf\?-8$'; then
	LOCALE_DIR="${REPO_ROOT}/.build-tools/locale"
	if [[ ! -d "${LOCALE_DIR}/en_US.UTF-8" ]]; then
		command -v localedef >/dev/null 2>&1 || {
			echo "Missing required UTF-8 locale en_US.UTF-8 and localedef is unavailable" >&2
			exit 1
		}
		mkdir -p "$LOCALE_DIR"
		localedef --no-archive -i en_US -f UTF-8 "${LOCALE_DIR}/en_US.UTF-8"
	fi
	# glibc normalizes the environment spelling to en_US.utf8 when looking up
	# LOCPATH entries, while BitBake requests en_US.UTF-8 explicitly.
	ln -sfn en_US.UTF-8 "${LOCALE_DIR}/en_US.utf8"
	export LOCPATH="$LOCALE_DIR"
fi
# Keep the parent shell on the always-present UTF-8 locale. BitBake switches
# its own locale to en_US.UTF-8 after startup; LOCPATH is preserved below.
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
# BitBake normally filters LOCPATH from its child environment. Preserve it so
# the repository-local locale generated above is visible to the cooker.
export BB_PRESERVE_ENV=1

# Network-enabled BitBake tasks (for example balena-supervisor's release API
# lookup) run in a sanitized environment. Preserve the conventional proxy
# variables when the host uses one, without embedding any host-specific value
# in the repository. Empty variables are harmless and are filtered by curl.
PASSTHROUGH_VARS="http_proxy https_proxy ftp_proxy no_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY NO_PROXY"
export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS:-} ${PASSTHROUGH_VARS}"

# Download/update the sources declared by this checkout.  Existing pinned
# submodule revisions are preserved; no source is taken from another clone.
# Pass the paths explicitly: older revisions of this repository may still
# contain a removed `layers/meta-rockchip` gitlink with no .gitmodules entry.
mapfile -t SUBMODULE_PATHS < <(
	git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}'
)
if ((${#SUBMODULE_PATHS[@]})); then
	git submodule sync --recursive "${SUBMODULE_PATHS[@]}"
	for submodule_path in "${SUBMODULE_PATHS[@]}"; do
		# Keep an existing checkout (including a locally selected Wrynose
		# branch) intact. A missing path is initialized from the gitlink.
		if [[ ! -e "${submodule_path}/.git" ]]; then
			git submodule update --init --recursive "$submodule_path"
		fi
	done
fi

# A previous invocation may have left a generated config behind. Normalized
# again after the build environment is initialized below, when a fresh
# conf/local.conf may have appeared. Rewrite only that ignored build file so
# a cache from another checkout can never leak into this build.
normalize_build_conf() {
	local BUILD_CONF="${REPO_ROOT}/${BUILD_DIR}/conf/local.conf"
	[[ -f "$BUILD_CONF" ]] || return 0
	if grep -Eq '^DL_DIR[[:space:]]*\??=' "$BUILD_CONF"; then
		sed -i -E 's#^DL_DIR[[:space:]]*\??=.*#DL_DIR = "${TOPDIR}/downloads"#' "$BUILD_CONF"
	else
		echo 'DL_DIR = "${TOPDIR}/downloads"' >> "$BUILD_CONF"
	fi
	if grep -Eq '^SSTATE_DIR[[:space:]]*\??=' "$BUILD_CONF"; then
		sed -i -E 's#^SSTATE_DIR[[:space:]]*\??=.*#SSTATE_DIR = "${TOPDIR}/sstate-cache"#' "$BUILD_CONF"
	else
		echo 'SSTATE_DIR = "${TOPDIR}/sstate-cache"' >> "$BUILD_CONF"
	fi
	# Normalize stale values written by older Barys versions without the
	# conventional whitespace around '='. This is only an ignored build file.
	sed -i -E \
		-e 's#^DL_DIR="(.*)"#DL_DIR = "\1"#' \
		-e 's#^SSTATE_DIR="(.*)"#SSTATE_DIR = "\1"#' \
		-e 's#^RK_SDK_ROOT="(.*)"#RK_SDK_ROOT = "\1"#' \
		"$BUILD_CONF"
}
normalize_build_conf

# Collect the flashable artifacts and the full build console log under
# output/ so nothing has to be hunted down in the deploy directory.
readonly OUTPUT_DIR="${REPO_ROOT}/output"
readonly IMAGE_OUT_DIR="${OUTPUT_DIR}/images"
readonly LOG_OUT_DIR="${OUTPUT_DIR}/logs"
mkdir -p "${IMAGE_OUT_DIR}" "${LOG_OUT_DIR}"

BUILD_LOG="${LOG_OUT_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
# tee writes as the build streams, so the log is a live view of the console
# output; latest.log always points at the most recent build.
ln -sfn "$(basename "${BUILD_LOG}")" "${LOG_OUT_DIR}/latest.log"
echo "[build] console log: ${BUILD_LOG}"

# Drive the Yocto environment directly instead of through barys: upstream
# barys cannot source oe-init-build-env with Wrynose's separate
# layers/bitbake checkout (it only knows the poky layout), which used to
# require a local patch inside the submodule.  The steps below replicate the
# parts of barys this build actually uses.
if (( CLEAN_BUILD )); then
	echo "[build] removing ${REPO_ROOT}/${BUILD_DIR}"
	rm -rf "${REPO_ROOT}/${BUILD_DIR}"
fi

export MACHINE
export TEMPLATECONF="${REPO_ROOT}/layers/meta-balena-rockchip/conf/templates/default"

# oe-init-build-env changes the working directory to the build directory and
# expects a less strict shell than "set -euo pipefail".
set +e +u
source "${REPO_ROOT}/layers/openembedded-core/oe-init-build-env" \
	"${REPO_ROOT}/${BUILD_DIR}" \
	"${REPO_ROOT}/layers/bitbake" >"${BUILD_LOG}.env" 2>&1
ENV_STATUS=$?
set -e -u
if (( ENV_STATUS != 0 )); then
	tee -a "${BUILD_LOG}" <"${BUILD_LOG}.env" >&2
	echo "[build] FAILED: oe-init-build-env exited ${ENV_STATUS}; see ${BUILD_LOG}" >&2
	exit "${ENV_STATUS}"
fi
rm -f "${BUILD_LOG}.env"

# barys-equivalent local.conf adjustments, now that conf/ exists.
normalize_build_conf
if (( DEVELOPMENT_IMAGE )); then
	sed -i 's#.*OS_DEVELOPMENT =.*#OS_DEVELOPMENT = "1"#g' "${REPO_ROOT}/${BUILD_DIR}/conf/local.conf"
else
	sed -i 's#.*OS_DEVELOPMENT =.*#OS_DEVELOPMENT = "0"#g' "${REPO_ROOT}/${BUILD_DIR}/conf/local.conf"
fi

# See image-balena.bbclass: this only removes the kernel-devsrc and
# kernel-headers-test build-time dependencies; the produced image is identical.
if (( DISABLE_KERNEL_HEADERS )); then
	export BALENA_DISABLE_KERNEL_HEADERS=1
fi

BITBAKE_ARGS=(balena-image-flasher)
if (( CONTINUE_BUILD )); then
	BITBAKE_ARGS=(-k "${BITBAKE_ARGS[@]}")
fi

set +e
bitbake "${BITBAKE_ARGS[@]}" 2>&1 | tee -a "${BUILD_LOG}"
BARYS_STATUS=${PIPESTATUS[0]}
set -e

if (( BARYS_STATUS != 0 )); then
	echo "[build] FAILED (exit ${BARYS_STATUS}); see ${BUILD_LOG}" >&2
	exit "${BARYS_STATUS}"
fi

# Unversioned copies of everything needed to flash a board.  cp -L resolves
# the deploy-directory symlinks so the copied names carry no timestamp.
DEPLOY_IMAGE_DIR="${REPO_ROOT}/${BUILD_DIR}/tmp/deploy/images/${MACHINE}"
copy_image() {
	local src="${DEPLOY_IMAGE_DIR}/$1"
	if [[ ! -e "${src}" ]]; then
		echo "[build] WARNING: expected artifact not found: ${src}" >&2
		return
	fi
	cp -fL "${src}" "${IMAGE_OUT_DIR}/$1"
	echo "[build] image: ${IMAGE_OUT_DIR}/$1"
}

copy_image balena-image-flasher-recomputer-rk3588-devkit.balenaos-img
copy_image balena-image-recomputer-rk3588-devkit.balenaos-img
copy_image rkspi_loader.img
copy_image spl_loader_maskrom.bin

echo "[build] done; images in ${IMAGE_OUT_DIR}, logs in ${LOG_OUT_DIR}"
