include balena-image.inc

# image_types_balena names BALENA_DOCKER_IMG after the DATETIME-versioned
# ${IMAGE_NAME}, so the file only exists when do_image_docker ran in the
# *current* build.  A bootloader-only change reruns do_image_balenaos_img
# (it depends on virtual/bootloader:do_deploy) with a fresh DATETIME while
# do_image_docker stays cached, and do_image_size_check then fails with
# FileNotFoundError.  Regenerate the docker image every build (~1 min) so
# the versioned names stay in lockstep.
do_image_docker[nostamp] = "1"

# do_resin_boot_dirgen_and_deploy only runs after do_rootfs upstream, but the
# boot partition files it copies come from the deploy directory; without an
# explicit deploy dependency a deploy-only change ships stale boot files.
do_resin_boot_dirgen_and_deploy[depends] += "virtual/kernel:do_deploy virtual/bootloader:do_deploy"

BALENA_BOOT_PARTITION_FILES:append:rockpi-4b-rk3399 = " \
    idbloader.img:/ \
    u-boot.itb:/ \
"

IMAGE_INSTALL:append:rockpi-4b-rk3399 = " u-boot-extlinux"

BALENA_BOOT_PARTITION_FILES:append:recomputer-rk3588-devkit = " \
    idbloader.img:/ \
    u-boot.itb:/ \
    ${KERNEL_IMAGETYPE}${KERNEL_INITRAMFS}-${MACHINE}.bin:/${KERNEL_IMAGETYPE} \
    rk3588-recomputer-rk3588-devkit-recomputer-rk3588-devkit.dtb:/rk3588-recomputer-rk3588-devkit.dtb \
    extlinux/extlinux.conf:/extlinux/extlinux.conf \
"

IMAGE_INSTALL:append:recomputer-rk3588-devkit = " u-boot-extlinux"
