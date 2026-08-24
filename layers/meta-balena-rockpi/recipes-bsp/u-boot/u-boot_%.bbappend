FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit resin-u-boot

SRC_URI:append:rockpi-4b-rk3399 = " \
    file://0001-Revert-Correct-SPL-use-of-CMD_ERASEENV.patch \
    file://0001-Revert-env-add-ENV_ERASE_PTR-macro.patch \
    file://balenaos_rockpi4b.cfg \
"

# Board files are kept as explicit layer inputs while the vendor U-Boot source
# is being converted from the existing Armbian worktree into reproducible
# Yocto patches.
SRC_URI:append:recomputer-rk3588-devkit = " \
    file://recomputer-rk3588-devkit_defconfig \
    file://rk3588-recomputer-rk3588-devkit.dts \
    file://0001-rockchip-use-python3-for-fit-generator.patch \
"

# Keep the base recipe's source and resin-u-boot integration inputs intact,
# but build from Radxa's RK35xx tree in a separate fetch destination.
SRC_URI:remove:recomputer-rk3588-devkit = "git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master"
# The Poky 2024.01 recipe adds CVE backports for its pinned mainline tree.
# They target files which do not exist in Radxa's vendor next-dev tree, so
# applying them to this machine would make do_patch fail before configuration.
# Keep this exception local to the vendor-tree machine; a future Radxa commit
# with matching upstream fixes should remove these entries and re-enable the
# applicable security patches.
SRC_URI:remove:recomputer-rk3588-devkit = " \
    file://CVE-2025-24857.patch \
    file://CVE-2024-57254.patch \
    file://CVE-2024-57255.patch \
    file://CVE-2024-57256.patch \
    file://CVE-2024-57257.patch \
    file://CVE-2024-57258-1.patch \
    file://CVE-2024-57258-2.patch \
    file://CVE-2024-57258-3.patch \
    file://CVE-2024-57259.patch \
    file://CVE-2024-42040.patch \
"
SRC_URI:append:recomputer-rk3588-devkit = " \
    git://github.com/radxa/u-boot.git;protocol=https;branch=next-dev-v2024.10;name=radxa;destsuffix=radxa \
"
SRCREV_radxa:recomputer-rk3588-devkit = "39cd993e5d6296635438e84f4576b3a9bf76f86e"
SRCREV_FORMAT:recomputer-rk3588-devkit = "radxa"
S:recomputer-rk3588-devkit = "${WORKDIR}/radxa"

# Radxa's vendor tree has a newer copy of Licenses/README than the
# mainline U-Boot 2024.01 recipe records.
LIC_FILES_CHKSUM:recomputer-rk3588-devkit = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

do_configure:prepend:recomputer-rk3588-devkit() {
    install -Dm0644 ${WORKDIR}/recomputer-rk3588-devkit_defconfig \
        ${S}/configs/${UBOOT_MACHINE}
    install -Dm0644 ${WORKDIR}/rk3588-recomputer-rk3588-devkit.dts \
        ${S}/arch/arm/dts/rk3588-recomputer-rk3588-devkit.dts
}

# Radxa's RK3588 tree builds u-boot.bin and SPL as part of the normal `all`
# target, but the Rockchip boot flow consumes a FIT u-boot.itb plus an RKSD
# idbloader.img.  Generate both in the recipe work directory so the standard
# u-boot deploy task can publish them for Balena image assembly.
do_compile:append:recomputer-rk3588-devkit() {
    install -d ${B}/arch/arm/mach-rockchip
    ln -sf ${S}/arch/arm/mach-rockchip/fit_nodes.sh \
        ${B}/arch/arm/mach-rockchip/fit_nodes.sh
    ln -sf ${S}/arch/arm/mach-rockchip/fit_args.sh \
        ${B}/arch/arm/mach-rockchip/fit_args.sh
    ln -sf ${S}/arch/arm/mach-rockchip/decode_bl31.py \
        ${B}/arch/arm/mach-rockchip/decode_bl31.py

    export BL31="${BL31}"
    cd ${B}
    srctree=. ${S}/arch/arm/mach-rockchip/make_fit_atf.sh > ${B}/u-boot.its
    ${B}/tools/mkimage -f ${B}/u-boot.its -E ${B}/u-boot.itb
    ${B}/tools/mkimage -n rk3588 -T rksd \
        -d ${B}/tpl/u-boot-tpl.bin:${B}/spl/u-boot-spl.bin \
        ${B}/idbloader.img
}

# partition 1 is used for idbloader.img,partition 2 for u-boot.itb, partition 3 is left empty for the new BSP but we keep it so we are backward compatible
BALENA_BOOT_PART:rockpi-4b-rk3399 = "4"
BALENA_DEFAULT_ROOT_PART:rockpi-4b-rk3399 = "5"

BALENA_UBOOT_DEVICES = "0 1"

# Create extlinux.conf for the internal image; this file will be stored in the rootfs' boot directory

UBOOT_EXTLINUX_LABELS = "balenaOS"
UBOOT_EXTLINUX_ROOT = "${resin_kernel_root}"
UBOOT_EXTLINUX_KERNEL_ARGS = "${os_cmdline}"

# Seeed reComputer RK3588 DevKit. The boot partition follows two raw loader
# entries in the Balena GPT image, so boot/rootA are partitions 3/4.
BALENA_BOOT_PART:recomputer-rk3588-devkit = "3"
BALENA_DEFAULT_ROOT_PART:recomputer-rk3588-devkit = "4"
BALENA_UBOOT_DEVICES:recomputer-rk3588-devkit = "0 1"

UBOOT_EXTLINUX_LABELS:recomputer-rk3588-devkit = "balenaOS"
UBOOT_EXTLINUX_ROOT:recomputer-rk3588-devkit = "${resin_kernel_root}"
UBOOT_EXTLINUX_KERNEL_ARGS:recomputer-rk3588-devkit = "${os_cmdline}"

# Ensure this isn't re-used from sstate
do_deploy[nostamp] = "1"

# Create extlinux.conf for the flasher image; this file will be stored in the boot partition
do_deploy:append() {
    KERNEL_CMDLINE_ARGS_FLASHER="earlycon console=tty1 console=ttyS2,1500000n8 rw root=LABEL=flash-rootA rootfstype=ext4 rootwait flasher"

    mkdir -p ${DEPLOY_DIR_IMAGE}/extlinux || true
    cat >${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf_flasher <<EOF
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /$(echo "${KERNEL_DEVICETREE}" | cut -d '/' -f 2)
    APPEND ${KERNEL_CMDLINE_ARGS_FLASHER}
EOF

}

do_deploy:append:recomputer-rk3588-devkit() {
    KERNEL_CMDLINE_ARGS_FLASHER="earlycon console=tty1 console=ttyS2,1500000n8 rw root=LABEL=flash-rootA rootfstype=ext4 rootwait flasher"

    install -d ${DEPLOY_DIR_IMAGE}/extlinux
    cat > ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf_flasher <<EOF
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /rk3588-recomputer-rk3588-devkit.dtb
    APPEND ${KERNEL_CMDLINE_ARGS_FLASHER}
EOF
}
