IMAGE_FSTYPES += "balenaos-img"

# Wrynose can change DATETIME/IMAGE_NAME between incremental BitBake
# invocations while reusing do_rootfs sstate. In that case the exact
# timestamped license manifest is not present even though an equivalent
# manifest for the same image recipe is available. Prefer the exact path,
# then use the newest manifest for the current image/machine prefix.
deploy_image_license_manifest() {
    IMAGE_LICENSE_MANIFEST=""

    for manifest_path in \
        "${LICENSE_DIRECTORY}/${IMAGE_NAME}/image_license.manifest" \
        "${LICENSE_DIRECTORY}/${IMAGE_NAME}/license.manifest" \
        "${LICENSE_DIRECTORY}/${SSTATE_PKGARCH}/${IMAGE_NAME}/license.manifest"; do
        if [ -f "${manifest_path}" ]; then
            IMAGE_LICENSE_MANIFEST="${manifest_path}"
            break
        fi
    done

    if [ -z "${IMAGE_LICENSE_MANIFEST}" ]; then
        IMAGE_LICENSE_MANIFEST=$(find \
            "${LICENSE_DIRECTORY}/${SSTATE_PKGARCH}" \
            -maxdepth 2 -type f \
            -path "*/${IMAGE_BASENAME}-${MACHINE}-*/license.manifest" \
            -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n 1 | cut -d ' ' -f 2-)
        if [ -n "${IMAGE_LICENSE_MANIFEST}" ]; then
            bbnote "Using latest matching license manifest for ${IMAGE_NAME}: ${IMAGE_LICENSE_MANIFEST}"
        fi
    fi

    if [ -z "${IMAGE_LICENSE_MANIFEST}" ]; then
        bbfatal "Unable to locate license for image '${IMAGE_NAME}'"
    fi

    if [ -d "${IMGDEPLOYDIR}" ]; then
        DEPLOY_IMAGE_LICENSE_MANIFEST="${IMGDEPLOYDIR}/${IMAGE_NAME}.rootfs.license.manifest"
        DEPLOY_SYMLINK_IMAGE_LICENSE_MANIFEST="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.license.manifest"
    else
        DEPLOY_IMAGE_LICENSE_MANIFEST="${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.license.manifest"
        DEPLOY_SYMLINK_IMAGE_LICENSE_MANIFEST="${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.license.manifest"
    fi
    cp -f "${IMAGE_LICENSE_MANIFEST}" "${DEPLOY_IMAGE_LICENSE_MANIFEST}"
    ln -sf "${IMAGE_NAME}.license.manifest" "${DEPLOY_SYMLINK_IMAGE_LICENSE_MANIFEST}"
}

PARTITION_TABLE_TYPE:radxa-cm3-io-rk3566 = "gpt"
PARTITION_TABLE_TYPE:rockpi-4b-rk3399 = "gpt"

DEVICE_SPECIFIC_SPACE:radxa-cm3-io-rk3566 = "40960"
DEVICE_SPECIFIC_SPACE:rockpi-4b-rk3399 = "40960"

# we need to increase the rootfs size
IMAGE_ROOTFS_SIZE:radxa-cm3-io-rk3566 = "487424"
IMAGE_ROOTFS_SIZE:radxa-zero-s905y2 = "487424"
IMAGE_ROOTFS_SIZE:rockpi-4b-rk3399 = "733184"
BALENA_BOOT_SIZE:rockpi-4b-rk3399 = "80960"

# for the Radxa CM3 add the dtb, u-boot scripts to rootfs /boot directory
IMAGE_INSTALL:append:radxa-cm3-io-rk3566 = " \
    kernel-devicetree \
    u-boot-radxa-cm3-io-scripts \
"

# add the dtb, overlays, u-boot scripts and u-boot binaries to rootfs /boot directory
IMAGE_INSTALL:append:radxa-zero-s905y2 = " \
    kernel-devicetree \
    linux-radxa-zero-overlays \
    u-boot-radxa-zero-bins \
    u-boot-radxa-zero-scripts \
"

BALENA_BOOT_PARTITION_FILES:append:radxa-zero-s905y2 = " \
    uEnv.txt:/ \
"

BALENA_BOOT_PARTITION_FILES:append:radxa-cm3-io-rk3566 = " \
    overlays/cm3-io-sata.dtbo:/overlays/cm3-io-sata.dtbo \
    overlays/radxa-cm3-io-hd101boe9365-display.dtbo:/overlays/radxa-cm3-io-hd101boe9365-display.dtbo \
    overlays/radxa-cm3-io-i2c0-hym8563.dtbo:/overlays/radxa-cm3-io-i2c0-hym8563.dtbo \
    overlays/radxa-cm3-io-radxa-10p1inch-display.dtbo:/overlays/radxa-cm3-io-radxa-10p1inch-display.dtbo \
    overlays/radxa-cm3-io-sharp-lq133t1jw01-without-hdmi.dtbo:/overlays/radxa-cm3-io-sharp-lq133t1jw01-without-hdmi.dtbo \
"

device_specific_configuration:rockpi-4b-rk3399() {
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader1 64 8063
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader2 16384 24575
    # this 3rd partition is not used anymore with the new meta-rockchip BSP but we keep it for backward compatibility
    parted -s ${BALENA_RAW_IMG} unit s mkpart trust 24576 32767
}

IMAGE_CMD:balenaos-img:append:rockpi-4b-rk3399 () {
    dd if=${DEPLOY_DIR_IMAGE}/idbloader.img of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=64
    dd if=${DEPLOY_DIR_IMAGE}/u-boot.itb of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=16384
}

device_specific_configuration:radxa-cm3-io-rk3566() {
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader1 64 8063
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader2 16384 24575
}

IMAGE_CMD:balenaos-img:append:radxa-cm3-io-rk3566 () {
    dd if=${DEPLOY_DIR_IMAGE}/idbloader.img of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=64
    dd if=${DEPLOY_DIR_IMAGE}/u-boot.itb of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=16384
}

IMAGE_CMD:balenaos-img:append:radxa-zero-s905y2 () {
    dd if=${DEPLOY_DIR_IMAGE}/u-boot.bin of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=1
}

# Ensure extlinux.conf files are deployed
do_rootfs_balenaos-img[depends] += " u-boot-rockpi-4:do_build "

BALENA_BOOT_SIZE_radxa-cm3-io-rk3566 = "40960"
BALENA_STATE_SIZE_radxa-cm3-io-rk3566 = "20480"
BALENA_BOOT_SIZE_radxa-zero-s905y2 = "40960"
BALENA_STATE_SIZE_radxa-zero-s905y2 = "20480"
BALENA_STATE_SIZE_rockpi-4b-rk3399 = "20480"

# Seeed reComputer RK3588 DevKit. Rockchip's SPL and U-Boot are written at
# fixed raw-disk offsets; the two GPT entries below keep those areas visible
# to Balena's image layout and leave boot/rootA at partitions 3/4.
PARTITION_TABLE_TYPE:recomputer-rk3588-devkit = "gpt"
DEVICE_SPECIFIC_SPACE:recomputer-rk3588-devkit = "40960"
IMAGE_ROOTFS_SIZE:recomputer-rk3588-devkit = "733184"
# Wrynose's uncompressed initramfs Image is larger than the previous
# baseline. Leave enough free space for atomic boot-file replacement.
BALENA_BOOT_SIZE:recomputer-rk3588-devkit = "180224"
BALENA_STATE_SIZE:recomputer-rk3588-devkit = "20480"

device_specific_configuration:recomputer-rk3588-devkit() {
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader1 64 8063
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader2 16384 24575
}

IMAGE_CMD:balenaos-img:append:recomputer-rk3588-devkit () {
    dd if=${DEPLOY_DIR_IMAGE}/idbloader.img of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=64
    dd if=${DEPLOY_DIR_IMAGE}/u-boot.itb of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=16384
}
