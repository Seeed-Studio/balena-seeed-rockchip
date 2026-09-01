SUMMARY = "Firmware for the AIC8800 SDIO WiFi/BT module on reComputer RK3588 DevKit"
DESCRIPTION = "Firmware set for the AIC8800D80 SDIO wireless module. The \
in-tree aic8800_sdio driver reads these files from AIC_FW_PATH \
(/lib/firmware/aic8800/SDIO/aic8800D80/). Extracted from the Armbian \
armbian-firmware package that ships on the reference Seeed image."
LICENSE = "CLOSED"
SRC_URI = "file://aic8800"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware/aic8800/SDIO
    cp -r ${S}/aic8800/SDIO/* ${D}${nonarch_base_libdir}/firmware/aic8800/SDIO/
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/aic8800/*"

INSANE_SKIP:${PN} += "arch"
