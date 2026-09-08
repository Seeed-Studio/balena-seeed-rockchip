SUMMARY = "Seeed RK3576 vendor Linux kernel (Armbian rk-6.1-rkr7.2)"
DESCRIPTION = "Linux 6.1 vendor kernel for the reComputer RK3576 DevKit, \
taken from Armbian's linux-rockchip repository (same Rockchip BSP lineage \
as the previous in-repo SDK snapshot, tracked upstream).  Board DTS files, \
the fiq-debugger console fixes and the rkaiq mesh-buffer uapi alignment are \
layered on top."
SECTION = "kernel"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

inherit kernel
inherit kernel-yocto

COMPATIBLE_MACHINE = "^recomputer-rk3576-devkit$"

# Same Armbian vendor branch as the RK3588 machine (the tree covers all
# rk35xx SoCs).  Pinned to the branch tip verified for this switch.
SRC_URI = "git://github.com/armbian/linux-rockchip.git;protocol=https;branch=rk-6.1-rkr7.2 \
    file://balena-rk3576.cfg \
    file://rk3576-recomputer-rk3576-devkit.dts \
    file://recomputer-rk3576-devkit-cam.dtsi \
    file://0001-fiq-debugger-keep-console-on-break.patch \
    file://0002-fiq-debugger-console-thread-lost-wakeup.patch \
    file://0003-fiq-debugger-lossless-tty-wake.patch \
    file://0004-uapi-rkisp-mesh-buf-num-2.patch \
"
SRCREV = "5ef479b1070b9d74dcefce859826176ce0eb5fe1"

PV = "6.1.172+armbian-rkr7.2"
KERNEL_VERSION_SANITY_SKIP = "1"

# The generic vendor defconfig enables drivers for many unrelated SoCs.  The
# Rockchip defconfig keeps the module set aligned with this 6.1 vendor tree
# and avoids compiling incompatible DRM drivers from other platforms.
KBUILD_DEFCONFIG = "rockchip_linux_defconfig"
# kernel-yocto's configme falls back to merge_config.sh -n (allnoconfig)
# when KCONFIG_MODE is unset and a defconfig file is present in UNPACKDIR.
# allnoconfig forces every symbol not explicitly listed in the defconfig to
# 'n' instead of its Kconfig default; CONFIG_TTY (which rockchip_linux_defconfig
# never lists because it defaults to y) gets disabled that way, which drops
# the whole serial subsystem (SERIAL_8250 depends on TTY) and produces a
# silent kernel.  Use alldefconfig so unlisted symbols keep their defaults.
KCONFIG_MODE = "alldefconfig"
KERNEL_IMAGETYPE = "Image"
KERNEL_DEVICETREE = "rockchip/rk3576-recomputer-rk3576-devkit.dtb"

# The vendor tree is SoC-complete but does not carry Seeed's board DTS.  Add
# only the board files and DTB registration to the source tree at configure
# time (installed from UNPACKDIR so bitbake's stamp tracking sees them).
do_configure:prepend:recomputer-rk3576-devkit() {
    install -Dm0644 ${UNPACKDIR}/rk3576-recomputer-rk3576-devkit.dts \
        ${S}/arch/arm64/boot/dts/rockchip/rk3576-recomputer-rk3576-devkit.dts
    install -Dm0644 ${UNPACKDIR}/recomputer-rk3576-devkit-cam.dtsi \
        ${S}/arch/arm64/boot/dts/rockchip/recomputer-rk3576-devkit-cam.dtsi
    if ! grep -q 'rk3576-recomputer-rk3576-devkit.dtb' \
        ${S}/arch/arm64/boot/dts/rockchip/Makefile; then
        printf '%s\n' 'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3576-recomputer-rk3576-devkit.dtb' \
            >> ${S}/arch/arm64/boot/dts/rockchip/Makefile
    fi
}

# Wrynose's buildpaths QA also scans generated kernel source files. These two
# Linux generators embed the absolute kernel-source path in a comment, which
# compiler prefix maps cannot rewrite because it is generated source text.
# Replace the build-root portion after generation so linux-*-src remains
# relocatable and passes the package QA check.
do_compile:append:recomputer-rk3576-devkit() {
    for generated in \
        ${B}/drivers/tty/vt/consolemap_deftbl.c \
        ${B}/lib/oid_registry_data.c; do
        if [ -f "${generated}" ]; then
            sed -i "s#${TMPDIR}#<yocto-tmpdir>#g" "${generated}"
        fi
    done
}

do_compile_kernelmodules:append:recomputer-rk3576-devkit() {
    for generated in \
        ${B}/drivers/tty/vt/consolemap_deftbl.c \
        ${B}/lib/oid_registry_data.c; do
        if [ -f "${generated}" ]; then
            sed -i "s#${TMPDIR}#<yocto-tmpdir>#g" "${generated}"
        fi
    done
}

# kernel-yocto's scc does not create its output directories: do_kernel_metadata
# (patch mode) and the config-mode metadata run embedded in do_kernel_configme
# write straight into ${S}/.kernel-meta, and do_kernel_configme itself
# redirects merge_config.sh output into ${S}/.kernel-meta/cfg, all of which
# fail with "Directory nonexistent" when nothing has created them yet.
# mkdir -p is idempotent even when both machines build from this tree.
do_kernel_metadata:prepend:recomputer-rk3576-devkit() {
    mkdir -p ${S}/.kernel-meta ${S}/.kernel-meta/cfg
}

do_kernel_configme:prepend:recomputer-rk3576-devkit() {
    mkdir -p ${S}/.kernel-meta ${S}/.kernel-meta/cfg
}
