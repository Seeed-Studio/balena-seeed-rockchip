DESCRIPTION = "Rockchip firmware and tool binaries from the staged official SDK"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://LICENSE;md5=11e3673115959bf596feaaa6ea7ce9a5"

inherit externalsrc deploy

# Keep the firmware source aligned with the kernel and U-Boot sources used by
# this machine.  No public rkbin Git repository is in the fetch path.
RK_SDK_ROOT ?= "${TOPDIR}/../bsp/rockchip-sdk"
EXTERNALSRC = "${RK_SDK_ROOT}/rkbin"
EXTERNALSRC_BUILD = "${WORKDIR}/rkbin-build"
S = "${EXTERNALSRC}"
SRC_URI = ""

PROVIDES += "trusted-firmware-a optee-os"
INHIBIT_DEFAULT_DEPS = "1"
PACKAGE_ARCH = "${MACHINE_ARCH}"
COMPATIBLE_MACHINE = "^(recomputer-rk3588-devkit|recomputer-rk3576-devkit)$"

PACKAGES = "${PN}"
ALLOW_EMPTY:${PN} = "1"

DDRBIN_VERS = "v1.21"
DDRBIN_FILE = "rk3588_ddr_lp4_2112MHz_lp5_2400MHz_${DDRBIN_VERS}.bin"

# RK3576 blobs: DDR v1.12 + BL31 v1.24 is the combination Seeed's armbian
# mainline-U-Boot path uses on this board.  (The armbian vendor branch
# deliberately stays on DDR v1.08 because v1.09 regressed on some boards;
# v1.12 is the next good generation and ships in the staged SDK rkbin.)
DDRBIN_VERS:recomputer-rk3576-devkit = "v1.12"
DDRBIN_FILE:recomputer-rk3576-devkit = "rk3576_ddr_lp4_2112MHz_lp5_2736MHz_${DDRBIN_VERS}.bin"

do_install() {
    :
}

do_deploy() {
    install -Dm0644 ${S}/bin/rk35/rk3588_bl31_v*.elf \
        ${DEPLOYDIR}/bl31-rk3588.elf
    install -Dm0644 ${S}/bin/rk35/rk3588_bl32_v*.bin \
        ${DEPLOYDIR}/tee-rk3588.bin
    install -Dm0644 ${S}/bin/rk35/${DDRBIN_FILE} \
        ${DEPLOYDIR}/ddr-rk3588.bin
}

do_deploy:append:recomputer-rk3576-devkit() {
    # The plain-name globs skip the _primary/_secondary AMP variants, which
    # have different filename shapes and are not part of this boot chain.
    install -Dm0644 ${S}/bin/rk35/rk3576_bl31_v*.elf \
        ${DEPLOYDIR}/bl31-rk3576.elf
    install -Dm0644 ${S}/bin/rk35/rk3576_bl32_v*.bin \
        ${DEPLOYDIR}/tee-rk3576.bin
    install -Dm0644 ${S}/bin/rk35/${DDRBIN_FILE} \
        ${DEPLOYDIR}/ddr-rk3576.bin
    # RK3576 idbloader is a three-segment RKSD image whose first segment is
    # the SRAM "boost" stage (0x3FFC0000), ahead of the DDR init and SPL.
    install -Dm0644 ${S}/bin/rk35/rk3576_boost_v1.03.bin \
        ${DEPLOYDIR}/boost-rk3576.bin
}

addtask deploy after do_install
