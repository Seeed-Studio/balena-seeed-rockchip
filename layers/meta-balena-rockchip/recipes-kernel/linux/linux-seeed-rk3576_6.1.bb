SUMMARY = "Seeed RK3576 vendor Linux kernel"
DESCRIPTION = "Linux 6.1 vendor kernel used by the reComputer RK3576 DevKit."
SECTION = "kernel"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

inherit kernel
inherit kernel-yocto
inherit externalsrc

COMPATIBLE_MACHINE = "^recomputer-rk3576-devkit$"

# The RK3576 shares the staged SDK kernel tree with RK3588.  All tree-local
# modifications there are either SoC-neutral (fiq-debugger console fixes,
# imx708 sensor driver, aic8800 SDIO driver) or per-board DTS files, which
# are installed from this layer with distinct names plus guarded Makefile
# registration lines.
RK_SDK_ROOT ?= "${TOPDIR}/../bsp/rockchip-sdk"
EXTERNALSRC:recomputer-rk3576-devkit = "${RK_SDK_ROOT}/source/kernel-6.1"
EXTERNALSRC_BUILD:recomputer-rk3576-devkit = "${WORKDIR}/kernel-build"

SRC_URI = "file://balena-rk3576.cfg \
    file://rk3576-recomputer-rk3576-devkit.dts \
    file://recomputer-rk3576-devkit-cam.dtsi \
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
KERNEL_DEVICETREE = "rockchip/rk3576-recomputer-rk3576-devkit.dtb"

# The official SDK is SoC-complete but does not carry Seeed's board DTS. Add
# only the board files and DTB registration from the Seeed Armbian adaptation
# to the SDK source tree at configure time.
do_configure:prepend:recomputer-rk3576-devkit() {
    # externalsrc removes do_patch, so apply the fiq-debugger console fix
    # here with a guard (same pattern as the u-boot recipe's vendor patches).
    # These fixes are already baked into the staged tree; the guarded applies
    # keep the tree self-healing if it is ever restored from a pristine SDK.
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
    # Align the rkisp mesh-buffer uapi with Seeed's rkaiq userspace: the
    # RKISP_CMD_GET_MESHBUF_INFO ioctl number encodes sizeof(struct
    # rkisp_meshbuf_info), so a kernel built with ISP2X_MESH_BUF_NUM=3
    # rejects the userspace command with ENOTTY and the 3A server dies
    # during CAC mesh-buffer setup (2026-09 bring-up).  Baked into the
    # staged tree; this guard keeps it self-healing like the fiq fixes.
    if ! grep -q 'Keep in sync with the userspace ABI' \
        ${S}/include/uapi/linux/rk-isp2-config.h; then
        patch -d ${S} -p1 --forward --batch \
            < ${THISDIR}/files/0004-uapi-rkisp-mesh-buf-num-2.patch
    fi
    # Installed from UNPACKDIR (SRC_URI): copies from THISDIR would be
    # invisible to bitbake's stamp tracking, so edits to the layer DTS files
    # would silently never reach the externalsrc tree.
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
# fail with "Directory nonexistent" when nothing has created them yet.  The
# RK3576 shares the externalsrc kernel tree with RK3588, so the directories
# may already exist from the other machine's build; mkdir -p is idempotent.
do_kernel_metadata:prepend:recomputer-rk3576-devkit() {
    mkdir -p ${S}/.kernel-meta ${S}/.kernel-meta/cfg
}

do_kernel_configme:prepend:recomputer-rk3576-devkit() {
    mkdir -p ${S}/.kernel-meta ${S}/.kernel-meta/cfg
}
