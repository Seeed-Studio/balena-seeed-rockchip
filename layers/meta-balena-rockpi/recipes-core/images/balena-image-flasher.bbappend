include balena-image.inc

BALENA_BOOT_PARTITION_FILES:append:rockpi-4b-rk3399 = " \
    extlinux/extlinux.conf_flasher:/extlinux/extlinux.conf \
    rk3399-rock-pi-4b.dtb:/ \
    ${KERNEL_IMAGETYPE}${KERNEL_INITRAMFS}-${MACHINE}.bin:/${KERNEL_IMAGETYPE} \
"

# increase the flasher boot partition size in order to fit the uncompressed Image kernel type
BALENA_BOOT_SIZE:rockpi-4b-rk3399="163840"

BALENA_BOOT_PARTITION_FILES:append:recomputer-rk3588-devkit = " \
    extlinux/extlinux.conf_flasher:/extlinux/extlinux.conf \
    rk3588-recomputer-rk3588-devkit.dtb:/ \
    ${KERNEL_IMAGETYPE}${KERNEL_INITRAMFS}-${MACHINE}.bin:/${KERNEL_IMAGETYPE} \
"

BALENA_BOOT_SIZE:recomputer-rk3588-devkit = "163840"
