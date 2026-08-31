include balena-image.inc

BALENA_BOOT_PARTITION_FILES:append:rockpi-4b-rk3399 = " \
    extlinux/extlinux.conf_flasher:/extlinux/extlinux.conf \
    rk3399-rock-pi-4b.dtb:/ \
    ${KERNEL_IMAGETYPE}${KERNEL_INITRAMFS}-${MACHINE}.bin:/${KERNEL_IMAGETYPE} \
"

# increase the flasher boot partition size in order to fit the uncompressed Image kernel type
BALENA_BOOT_SIZE:rockpi-4b-rk3399 = "163840"

BALENA_BOOT_PARTITION_FILES:append:recomputer-rk3588-devkit = " \
    extlinux/extlinux.conf_flasher:/extlinux/extlinux.conf \
    rk3588-recomputer-rk3588-devkit.dtb:/ \
    ${KERNEL_IMAGETYPE}${KERNEL_INITRAMFS}-${MACHINE}.bin:/${KERNEL_IMAGETYPE} \
"

# Wrynose's uncompressed initramfs Image is larger than the previous
# baseline. Leave enough free space for atomic boot-file replacement.
BALENA_BOOT_SIZE:recomputer-rk3588-devkit = "180224"

# do_resin_boot_dirgen_and_deploy only runs after do_rootfs upstream, but the
# boot partition files it copies (kernel bundle, dtb, the generated extlinux
# and the raw loaders) come from the deploy directory.  When only a deploy
# artifact changes -- e.g. the extlinux.conf generated in u-boot's do_deploy
# -- the task stays cached and the rebuilt image ships stale boot files.
do_resin_boot_dirgen_and_deploy[depends] += "virtual/kernel:do_deploy virtual/bootloader:do_deploy"
