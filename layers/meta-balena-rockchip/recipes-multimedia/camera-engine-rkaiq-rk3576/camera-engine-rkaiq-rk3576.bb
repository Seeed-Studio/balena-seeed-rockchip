# Copyright (C) 2026 Seeed Studio
# Released under the MIT license (see COPYING.MIT for the terms)
#
# RKAIQ 3A engine for RK3576, repackaged from Seeed's prebuilt deb.
#
# The source-built rockchip-rkaiq recipe cannot serve this machine: the
# rk3576-side closed-source 3A algorithm .a blobs in the deb_source source
# tree are still broken when linked with the Wrynose toolchain (RK3588
# phase-5 leftover #11), and Seeed's own deb is deliberately built with the
# Arm GCC 8.3 toolchain "required by closed-source 3A algorithm libraries".
# The deb ships fully prelinked binaries/libraries, so no host linking is
# needed and the runtime only requires glibc/libstdc++/libdrm (already in
# the image via gstreamer/mpp).  Until the rk3576 blobs are fixed upstream,
# this package is the supported distribution channel:
#   https://github.com/Seeed-Studio/seeed_armbian_extension/tree/deb_source/prebuilt
#
# The IQ profiles cover both board camera seats (imx219 Pi Camera v2 /
# imx708 Pi Camera v3 + DW9817 VCM), matching the cam dtsi.
#
# TODO(upstream): switch back to a source-built recipe for rk3576 once the
# prebuilt .a blobs link cleanly; keep SRCREV provenance from the deb
# branch (camera-engine-rkaiq-rk3576_1.0-1, sha256 below).

SUMMARY = "Rockchip RKAIQ camera engine for RK3576 (prebuilt)"
DESCRIPTION = "Rockchip ISP 3A runtime libraries, rkaiq_3A_server and camera tuning profiles for the RK3576 SoC, repackaged from Seeed's prebuilt deb."
LICENSE = "CLOSED"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

PACKAGE_ARCH = "${MACHINE_ARCH}"
COMPATIBLE_MACHINE = "^recomputer-rk3576-devkit$"

SRC_URI = "https://raw.githubusercontent.com/Seeed-Studio/seeed_armbian_extension/deb_source/prebuilt/camera-engine-rkaiq-rk3576_1.0-1_arm64.deb;downloadfilename=camera-engine-rkaiq-rk3576_1.0-1_arm64.deb;subdir=rkaiq-deb \
    file://rkaiq_3A.service \
"
SRC_URI[sha256sum] = "879c9925f8eae1e1b03075e9ed73770c8f99323de095a0c11f1843d45ba4b59b"

PV = "1.0"
PR = "r0"

# The splits must precede PN in PACKAGES: usrmerge puts the systemd unit
# under /usr/lib/systemd/system, which PN's ${libdir} glob would otherwise
# claim (enablement is handled by the class preset at rootfs time).
PACKAGE_BEFORE_PN = "${PN}-server ${PN}-iqfiles"

RDEPENDS:${PN}-server = "${PN}"
# Explicit: the prelinked librkaiq.so needs libdrm.so.2, and file-rdeps
# QA cannot auto-resolve it from a repackaged binary.
RDEPENDS:${PN} = "libdrm"

SYSTEMD_PACKAGES = "${PN}-server"
SYSTEMD_SERVICE:${PN}-server = "rkaiq_3A.service"
SYSTEMD_AUTO_ENABLE:${PN}-server = "enable"

inherit systemd

# BitBake's unpack extracts the deb archive straight into
# ${UNPACKDIR}/rkaiq-deb (etc/lib/usr), so do_install only reshuffles
# the prelinked payload; no host toolchain touches the closed blobs.
do_install() {
    EX=${UNPACKDIR}/rkaiq-deb

    # Runtime libraries (prelinked, closed 3A blobs already inside).
    install -d ${D}${libdir}
    install -m 0644 ${EX}/usr/lib/librkaiq.so* ${D}${libdir}/
    install -m 0644 ${EX}/usr/lib/libIspFec.so* ${D}${libdir}/
    install -m 0644 ${EX}/usr/lib/libsmartIr.so* ${D}${libdir}/
    install -m 0644 ${EX}/usr/lib/librkrawstream.so* ${D}${libdir}/

    # 3A server with our hardened unit (direct ExecStart, restart rate
    # limit, capped stop timeout) instead of the deb's sysv wrapper.
    install -d ${D}${bindir} ${D}${systemd_system_unitdir}
    install -m 0755 ${EX}/usr/bin/rkaiq_3A_server ${D}${bindir}/
    install -m 0644 ${UNPACKDIR}/rkaiq_3A.service \
        ${D}${systemd_system_unitdir}/

    # IQ profiles: flat json set, covering imx219/imx708 (both cam seats).
    install -d ${D}${sysconfdir}/iqfiles
    install -m 0644 ${EX}/etc/iqfiles/*.json ${D}${sysconfdir}/iqfiles/
}

FILES:${PN}-server = " \
    ${bindir}/rkaiq_3A_server \
    ${systemd_system_unitdir}/rkaiq_3A.service \
"
FILES:${PN}-iqfiles = "${sysconfdir}/iqfiles"

# The deb ships unversioned .so files (no soname suffixes, no symlinks):
# they are the runtime libraries, so claim them for PN explicitly or the
# default -dev split grabs them and QA rejects non-symlink .so in -dev.
# No headers ship, leaving -dev empty on purpose.
FILES:${PN} = " \
    ${libdir}/librkaiq.so* \
    ${libdir}/libIspFec.so* \
    ${libdir}/libsmartIr.so* \
    ${libdir}/librkrawstream.so* \
"
FILES:${PN}-dev = ""

# The .a archives, headers, dumpcam/rkaiq_tool_server debugging tools and
# the deb's sysv/init scripts are not shipped; the source recipe drops the
# same tool set on RK3588.
