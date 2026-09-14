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

# Seeed reComputer RK3576 DevKit.  Identical raw loader layout to RK3588
# (idbloader at sector 64, u-boot.itb at sector 16384; the RK3576 boot ROM
# uses the same loader slots), so boot/rootA stay at partitions 3/4.
PARTITION_TABLE_TYPE:recomputer-rk3576-devkit = "gpt"
DEVICE_SPECIFIC_SPACE:recomputer-rk3576-devkit = "40960"
IMAGE_ROOTFS_SIZE:recomputer-rk3576-devkit = "733184"
BALENA_BOOT_SIZE:recomputer-rk3576-devkit = "180224"
BALENA_STATE_SIZE:recomputer-rk3576-devkit = "20480"

device_specific_configuration:recomputer-rk3576-devkit() {
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader1 64 8063
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader2 16384 24575
}

IMAGE_CMD:balenaos-img:append:recomputer-rk3576-devkit () {
    dd if=${DEPLOY_DIR_IMAGE}/idbloader.img of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=64
    dd if=${DEPLOY_DIR_IMAGE}/u-boot.itb of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=16384
}
