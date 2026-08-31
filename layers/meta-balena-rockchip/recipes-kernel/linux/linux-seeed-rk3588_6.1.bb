SUMMARY = "Seeed RK3588 vendor Linux kernel"
DESCRIPTION = "Linux 6.1 vendor kernel used by the reComputer RK3588 DevKit."
SECTION = "kernel"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

inherit kernel
inherit kernel-yocto
inherit externalsrc

COMPATIBLE_MACHINE = "^recomputer-rk3588-devkit$"

RK_SDK_ROOT ?= "${TOPDIR}/../bsp/rockchip-sdk"
EXTERNALSRC:recomputer-rk3588-devkit = "${RK_SDK_ROOT}/source/kernel-6.1"
EXTERNALSRC_BUILD:recomputer-rk3588-devkit = "${WORKDIR}/kernel-build"

SRC_URI = "file://balena-rk3588.cfg \
    file://0001-fiq-debugger-keep-console-on-break.patch \
    file://0002-fiq-debugger-console-thread-lost-wakeup.patch \
    file://0003-fiq-debugger-lossless-tty-wake.patch \
"

PV = "6.1.141+rockchip-sdk"
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
KERNEL_DEVICETREE = "rockchip/rk3588-recomputer-rk3588-devkit.dtb"
# The recipe uses kernel-yocto so the .cfg in SRC_URI is merged through the
# standard kernel metadata queue. meta-rockchip also adds a kmeta feature for
# its linux-yocto recipes; this independent vendor tree does not carry that
# kmeta repository, so do not request the dangling feature here.
KERNEL_FEATURES:remove:recomputer-rk3588-devkit = "bsp/rockchip/remove-non-rockchip-arch-arm64.scc"

# The official SDK is SoC-complete but does not carry Seeed's board DTS. Add
# only the board files and DTB registration from the Seeed Armbian adaptation
# to the SDK source tree at configure time.
do_configure:prepend:recomputer-rk3588-devkit() {
    # externalsrc removes do_patch, so apply the fiq-debugger console fix
    # here with a guard (same pattern as the u-boot recipe's vendor patches).
    if ! grep -q 'c == FIQ_DEBUGGER_BREAK && !state->console_enable' \
        ${S}/drivers/soc/rockchip/fiq_debugger/fiq_debugger.c; then
        patch -d ${S} -p1 --forward --batch \
            < ${THISDIR}/files/0001-fiq-debugger-keep-console-on-break.patch
    fi
    if ! grep -q 'keep draining if new' \
        ${S}/drivers/soc/rockchip/fiq_debugger/rk_fiq_debugger.c; then
        patch -d ${S} -p1 --forward --batch \
            < ${THISDIR}/files/0002-fiq-debugger-console-thread-lost-wakeup.patch
    fi
    if ! grep -q 'no user-visible output can' \
        ${S}/drivers/soc/rockchip/fiq_debugger/rk_fiq_debugger.c; then
        patch -d ${S} -p1 --forward --batch \
            < ${THISDIR}/files/0003-fiq-debugger-lossless-tty-wake.patch
    fi
    install -Dm0644 ${THISDIR}/files/rk3588-recomputer-rk3588-devkit.dts \
        ${S}/arch/arm64/boot/dts/rockchip/rk3588-recomputer-rk3588-devkit.dts
    install -Dm0644 ${THISDIR}/files/recomputer-rk3588-devkit-cam.dtsi \
        ${S}/arch/arm64/boot/dts/rockchip/recomputer-rk3588-devkit-cam.dtsi
    if ! grep -q 'rk3588-recomputer-rk3588-devkit.dtb' \
        ${S}/arch/arm64/boot/dts/rockchip/Makefile; then
        printf '%s\n' 'dtb-$(CONFIG_ARCH_ROCKCHIP) += rk3588-recomputer-rk3588-devkit.dtb' \
            >> ${S}/arch/arm64/boot/dts/rockchip/Makefile
    fi
}

# Wrynose's buildpaths QA also scans generated kernel source files. These two
# Linux generators embed the absolute kernel-source path in a comment, which
# compiler prefix maps cannot rewrite because it is generated source text.
# Replace the build-root portion after generation so linux-*-src remains
# relocatable and passes the package QA check.
do_compile:append:recomputer-rk3588-devkit() {
    for generated in \
        ${B}/drivers/tty/vt/consolemap_deftbl.c \
        ${B}/lib/oid_registry_data.c; do
        if [ -f "${generated}" ]; then
            sed -i "s#${TMPDIR}#<yocto-tmpdir>#g" "${generated}"
        fi
    done
}

do_compile_kernelmodules:append:recomputer-rk3588-devkit() {
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
# fail with "Directory nonexistent" when nothing has created them yet.  With
# externalsrc the source tree persists between builds, so the directories only
# went missing after the first clean rebuild wiped the leftover state.
do_kernel_metadata:prepend:recomputer-rk3588-devkit() {
    mkdir -p ${S}/.kernel-meta ${S}/.kernel-meta/cfg
}

do_kernel_configme:prepend:recomputer-rk3588-devkit() {
    mkdir -p ${S}/.kernel-meta ${S}/.kernel-meta/cfg
}
