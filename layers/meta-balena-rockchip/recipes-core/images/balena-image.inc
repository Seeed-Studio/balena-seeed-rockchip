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
# Sized for the meta-rockchip rkaiq+rkisp camera stack in IMAGE_INSTALL;
# 733184 KiB failed the HUP size check by ~24 MiB once rkisp was added.
IMAGE_ROOTFS_SIZE:recomputer-rk3588-devkit = "798720"
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
# Sized for the meta-rockchip rkaiq+rkisp camera stack in IMAGE_INSTALL;
# 733184 KiB failed the HUP size check by ~24 MiB once rkisp was added.
IMAGE_ROOTFS_SIZE:recomputer-rk3576-devkit = "798720"
BALENA_BOOT_SIZE:recomputer-rk3576-devkit = "180224"
BALENA_STATE_SIZE:recomputer-rk3576-devkit = "20480"

device_specific_configuration:recomputer-rk3576-devkit() {
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader1 64 8063
    parted -s ${BALENA_RAW_IMG} unit s mkpart loader2 16384 24575
}

IMAGE_CMD:balenaos-img:append:recomputer-rk3576-devkit () {
    dd if=${DEPLOY_DIR_IMAGE}/idbloader.img of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=64
    dd if=${DEPLOY_DIR_IMAGE}/u-boot.itb of=${BALENA_RAW_IMG} conv=notrunc bs=512 seek=16384

    # Shrink the GPT partition-entry table from the parted default 128
    # entries to 16 (this image only has 7).  The stock SPI SPL parses
    # the GPT (primary + backup) with a bump allocator that never frees,
    # so 128 entries cost 16 KiB per scan and push the final
    # memalign_simple() for the u-boot FIT image over the early-pool
    # cliff; the NULL buffer then aborts in dcache maintenance.  16
    # entries keep every partition LBA/UUID/label identical and free
    # ~28 KiB of the pool instead.
    python3 - "${BALENA_RAW_IMG}" <<'PYEOF'
import struct, sys, zlib

img = sys.argv[1]
ss = 512

def shrink(hdr):
    # UEFI GPT header: NumberOfPartitionEntries is a UINT32 at offset 80,
    # SizeOfPartitionEntry a UINT32 at 84, entry-array CRC at 88.
    n = struct.unpack_from('<I', hdr, 80)[0]
    if n == 16:
        return False
    assert n == 128, f"unexpected GPT entries count {n}"
    struct.pack_into('<I', hdr, 80, 16)
    return True

def fixup_crcs(f, hdr_lba):
    f.seek(hdr_lba * ss)
    hdr = bytearray(f.read(ss))
    assert hdr[0:8] == b'EFI PART', f"no GPT header at LBA {hdr_lba}"
    if not shrink(hdr):
        return
    pte_lba = struct.unpack_from('<Q', hdr, 72)[0]
    # entry-array CRC now covers 16 * 128 bytes from the declared PTE LBA
    f.seek(pte_lba * ss)
    pte_crc = zlib.crc32(f.read(16 * 128)) & 0xffffffff
    struct.pack_into('<I', hdr, 88, pte_crc)
    # header CRC over the first 92 bytes with the CRC field zeroed
    struct.pack_into('<I', hdr, 16, 0)
    struct.pack_into('<I', hdr, 16, zlib.crc32(bytes(hdr[:92])) & 0xffffffff)
    f.seek(hdr_lba * ss)
    f.write(hdr)

with open(img, 'r+b') as f:
    f.seek(0, 2)
    last_lba = f.tell() // ss - 1
    fixup_crcs(f, 1)          # primary header
    fixup_crcs(f, last_lba)   # backup header
print("GPT partition entries shrunk 128 -> 16")
PYEOF
}
