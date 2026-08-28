#!/usr/bin/env bash
# Build balenaOS for the Seeed reComputer RK3588 DevKit.
#
# All Yocto output, downloads and shared-state cache are kept in paths derived
# from this repository. Nothing is written to another clone.
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly MACHINE="recomputer-rk3588-devkit"
readonly TEMPLATE_PATH="layers/meta-balena-rockpi/conf/templates/default"

BUILD_DIR="build-recomputer-rk3588-devkit"
CLEAN_BUILD=0

usage() {
	cat <<'EOF'
Usage: scripts/build-recomputer-rk3588-devkit.sh [--clean] [--continue] [--build-dir DIR]

Builds balena-image-flasher for recomputer-rk3588-devkit.

  --clean             remove the selected build directory before building
  --continue          continue as much as possible after a task failure
  --build-dir DIR     repository-relative build directory name (default:
                      build-recomputer-rk3588-devkit)

The build directory contains tmp/, downloads/ and sstate-cache/.  They are
local build artifacts and are excluded from Git.
EOF
}

CONTINUE_BUILD=0
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

# A previous invocation may have left a generated config behind. Rewrite only
# that ignored build file so a cache from another checkout can never leak into
# this build.
BUILD_CONF="${REPO_ROOT}/${BUILD_DIR}/conf/local.conf"
if [[ -f "$BUILD_CONF" ]]; then
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
fi

BARYS_ARGS=(
	--machine "$MACHINE"
	--build-name "$BUILD_DIR"
	--templates-path "$TEMPLATE_PATH"
)

if (( CLEAN_BUILD )); then
	BARYS_ARGS+=(--remove-build)
fi

if (( CONTINUE_BUILD )); then
	BARYS_ARGS+=(--continue)
fi

exec ./balena-yocto-scripts/build/barys "${BARYS_ARGS[@]}"
