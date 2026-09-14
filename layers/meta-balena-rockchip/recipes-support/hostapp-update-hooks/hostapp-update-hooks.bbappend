FILESEXTRAPATHS:append := ":${THISDIR}/files"

HOSTAPP_HOOKS += "99-resin-uboot 99-flash-bootloader-rockchip"

SRC_URI:append = " file://0001-99-resin-uboot-use-basename-for-blockdev.patch;patchdir=${UNPACKDIR}"
