FILESEXTRAPATHS:append := ":${THISDIR}/files"

HOSTAPP_HOOKS += "99-resin-uboot"

HOSTAPP_HOOKS:append:rockpi-4b-rk3399 = " \
    99-flash-bootloader \
"

HOSTAPP_HOOKS:append:recomputer-rk3588-devkit = " \
    99-flash-bootloader-recomputer-rk3588-devkit \
"

SRC_URI:append = " file://0001-99-resin-uboot-use-basename-for-blockdev.patch;patchdir=${UNPACKDIR}"

HOSTAPP_HOOKS:append:recomputer-rk3576-devkit = " \
    99-flash-bootloader-recomputer-rk3576-devkit \
"
