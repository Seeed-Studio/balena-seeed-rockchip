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
COMPATIBLE_MACHINE = "^recomputer-rk3588-devkit$"

PACKAGES = "${PN}"
ALLOW_EMPTY:${PN} = "1"

DDRBIN_VERS = "v1.21"
DDRBIN_FILE = "rk3588_ddr_lp4_2112MHz_lp5_2400MHz_${DDRBIN_VERS}.bin"

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

addtask deploy after do_install
