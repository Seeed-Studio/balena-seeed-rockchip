# Copyright (C) 2026 Seeed Studio
# Released under the MIT license (see COPYING.MIT for the terms)
#
# rkaiq 3A engine, source-built v6.0x8.0 tree as validated by Seeed on the
# reComputer rk3588 devkit with the Pi Camera v3 (IMX708): the vendor public
# snapshot plus three board-proven fixes (see the Seeed-side writeup at
# ~/workspace/rk3588/经验/camera-rkaiq-源码编译修复方案.md):
#   cd14f98  3A stats threads fall back to SCHED_OTHER when the RT policy is
#            denied - mandatory on balenaOS: systemd units carry no RT budget,
#            SCHED_RR is EPERM, and without the fallback the thread dies
#            silently and AE runs open-loop (frozen exposure / overexposure).
#   d9d2f21  authentic imx708 IQ jsons (isp3x + isp39 slots)
#   07bebb0  rkaiq_3A.service stop-timeout cap
# The engine binds sensors through the media graph and does NOT need the
# Rockchip rkmodule driver API, so the plain V4L2 imx708 driver gets 3A.
#
# This recipe intentionally shadows the SDK's
# bsp/rockchip-sdk/yocto/meta-rockchip/recipes-multimedia/rockchip-rkaiq/
# rockchip-rkaiq.bb (layer priority 1337 vs 9).  The SDK recipe builds the
# rkaiq-2024_04_08 snapshot, whose engine generation cannot pair with the
# v6.0x8.0 IQ format (dead end proven during the Seeed Armbian A/B tests).
#
# TODO(upstream): fetch from Seeed-Studio/seeed_armbian_extension once the
# deb_source branch lands in the official repo; keep SRCREV d0c0355 or
# fast-forward to the official tip after re-verifying.

LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://NOTICE;md5=9645f39e9db895a4aa6e02cb57294595"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# The splits must precede PN in PACKAGES: usrmerge puts the systemd unit
# under /usr/lib/systemd/system, which PN's ${libdir} glob would otherwise
# claim (enablement is handled by the class preset at rootfs time).
PACKAGE_BEFORE_PN = "${PN}-server ${PN}-iqfiles"

DEPENDS = "coreutils-native chrpath-replacement-native xxd-native libdrm rockchip-librga"

RDEPENDS:${PN}-server = "${PN}"

PACKAGE_ARCH = "${MACHINE_ARCH}"

SRC_URI = " \
    git://github.com/Panzhifeng-seeed/seeed_armbian_extension.git;protocol=https;nobranch=1;subpath=camera_engine_rkaiq \
    file://rkaiq_3A.service \
"
SRCREV = "d0c035512c92e6d82eb4b0f3d4cc7bdba75c0384"
# Wrynose requires S relative to UNPACKDIR (WORKDIR is rejected by QA).
S = "${UNPACKDIR}/camera_engine_rkaiq"

inherit pkgconfig cmake systemd

# The tree copies prebuilt .a blobs (pdaf, gen_mesh, ...) with plain custom
# targets that declare no BYPRODUCTS; Ninja rejects the build graph ("no
# known rule to make librkaiq_pdaf.a").  The vendor/deb builds drive Unix
# Makefiles - do the same here.
OECMAKE_GENERATOR = "Unix Makefiles"

# Same knobs build-cross.sh passes for rk3588.  ARCH and ISP_HW_VERSION are
# derived inside the tree's CMakeLists (rk3588 -> -DISP_HW_V30).
EXTRA_OECMAKE = " \
    -DRKAIQ_TARGET_SOC=${RK_SOC_FAMILY} \
    -DRKAIQ_ENABLE_LIBDRM=ON \
    -DRKAIQ_ENABLE_AF=ON \
    -DRKAIQ_HAVE_MULTIISP=ON \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
"

SYSTEMD_PACKAGES = "${PN}-server"
SYSTEMD_SERVICE:${PN}-server = "rkaiq_3A.service"
SYSTEMD_AUTO_ENABLE:${PN}-server = "enable"

do_generate_toolchain_file:append () {
	echo "set( CMAKE_SYSROOT ${STAGING_DIR_HOST} )" >> \
		${UNPACKDIR}/toolchain.cmake
	echo "set( CMAKE_SYSROOT_COMPILE ${STAGING_DIR_HOST} )" >> \
		${UNPACKDIR}/toolchain.cmake

	# Same cross fixes the SDK recipe applies; every target below exists in
	# the v6.0x8.0 tree (its xmltags.cpp fix is 2024-tree-only, not needed).
	sed -i "s/\( \${CMAKE_C_COMPILER}\)/\1 -I\${CMAKE_SYSROOT}\/usr\/include/" \
		${S}/rkaiq/iq_parser_v2/CMakeLists.txt

	sed -i '/\<prebuilts\>/d' ${S}/rkaiq_3A_server/CMakeLists.txt
	sed -i 's/\(add_library(.* STATIC IMPORTED\))/\1 GLOBAL)/' \
		${S}/rkaiq/algos/CMakeLists.txt
	# The tree predates the Wrynose host GCC; keep -Werror out of it.
	sed -i 's/-Werror//' ${S}/rkaiq/cmake/CompileOptions.cmake
	sed -i '/#include <stdlib.h>/i#include <stdio.h>' \
		${S}/rkaiq/ipc_server/MessageParser.hpp
}

do_install:append () {
	# libdir might not equal /usr/lib which is assumed by rkaiq's cmake
	if [ "${libdir}" != "/usr/lib" ]; then
		mkdir -p ${D}${libdir}
		mv ${D}/usr/lib/*.a ${D}${libdir}/ || true
		mv ${D}/usr/lib/*.so ${D}${libdir}/ || true
		rmdir --ignore-fail-on-non-empty ${D}/usr/lib
	fi

	# rkaiq installed the 3A server to the wrong dir.
	[ ! -d ${D}/usr/usr ] || cp -rp ${D}/usr/usr ${D}/

	# Drop unused tools
	rm -rf ${D}/usr/etc ${D}/usr/usr ${D}/usr/bin/*demo \
		${D}/usr/bin/rkaiq_tool_server ${D}/usr/bin/dumpcam

	[ -f ${D}${libdir}/libsmartIr.so ] && \
		chrpath -d ${D}${libdir}/libsmartIr.so || true

	# systemd unit (the tree ships one under debian/, keep ours: same design
	# plus the start rate limit).
	install -d ${D}${systemd_system_unitdir}
	install -m 0644 ${UNPACKDIR}/rkaiq_3A.service \
		${D}${systemd_system_unitdir}/

	# IQ files: flat *.json from the machine's ISP generation directory
	# (isp3.0 -> isp30, bridged to the tree's isp3x layout).
	install -d ${D}${sysconfdir}/iqfiles
	ln -sf isp3x ${S}/rkaiq/iqfiles/isp30
	IQFILES_DIR="$(echo isp${RK_ISP_VERSION} | tr 'A-Z' 'a-z' | tr -d '.')"
	install -m 0644 ${S}/rkaiq/iqfiles/${IQFILES_DIR}/*.json \
		${D}${sysconfdir}/iqfiles/
}

FILES:${PN}-dev = "${includedir}"
FILES:${PN}-server = " \
	${bindir}/rkaiq_3A_server \
	${systemd_system_unitdir}/rkaiq_3A.service \
	${systemd_unitdir}/system-preset/ \
"
FILES:${PN}-iqfiles = "${sysconfdir}/iqfiles/"
FILES:${PN} = " \
	${libdir} \
	${datadir} \
"
