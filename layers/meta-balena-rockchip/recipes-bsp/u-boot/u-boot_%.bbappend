FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit resin-u-boot

SRC_URI:append:rockpi-4b-rk3399 = " \
    file://0001-Revert-Correct-SPL-use-of-CMD_ERASEENV.patch \
    file://0001-Revert-env-add-ENV_ERASE_PTR-macro.patch \
    file://balenaos_rockpi4b.cfg \
"

# Both reComputer machines build U-Boot from the Radxa vendor tree that
# Seeed's Armbian integration builds for the same boards (BOOTSOURCE in
# its seeed-rk3588/seeed-rk3576 family configs).  The branch carries the
# 2024.10 code base with the Rockchip vendor boot flow (NEW_IDB loader,
# make_fit_atf FIT assembly, vendor partitions) on top; its Makefile
# still says 2017.09 because Rockchip pins the version string.  Pinned
# to the branch tip of 2026-04-27, the revision Seeed's u-boot patches
# are validated against.
RADXA_UBOOT_SRCURI = "git://github.com/radxa/u-boot.git;protocol=https;branch=next-dev-v2024.10"
RADXA_UBOOT_SRCREV = "39cd993e5d6296635438e84f4576b3a9bf76f86e"

SRC_URI:prepend:recomputer-rk3588-devkit = "${RADXA_UBOOT_SRCURI} "
# Both the release variant (tag=v${PV}) and the devupstream variant
# (plain branch=master) must go: each machine pins the Radxa tree instead.
SRC_URI:remove:recomputer-rk3588-devkit = "git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master;tag=v${PV} \
    git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master"
SRCREV:recomputer-rk3588-devkit = "${RADXA_UBOOT_SRCREV}"

# The board defconfig starts from the Seeed Armbian overlay defconfig
# (written for this exact tree) plus the BalenaOS delta documented at
# the bottom of the file.  The patch series: charge-animation build fix,
# balena bootcommand, NVMe distro-boot env + PCI enumeration, the three
# RK3588 sdhci/eMMC fixes (chained: 0007 must precede 0008/0010), the
# decimal setexpr for the hostapp A/B rollback counter, and the SFC
# unaligned-write fix (the SDK tree carried this fix inside
# drivers/rkflash/sfc.c and the Radxa tree does not - Seeed ships the
# identical backport for the maskrom usbplug and the in-tree SFC driver).
SRC_URI:append:recomputer-rk3588-devkit = " \
    file://recomputer-rk3588-devkit_defconfig \
    file://rk3588-recomputer-rk3588-devkit.dts \
    file://rk3588-maskrom.ini \
    file://0002-rk3588-charge-animation-initialize-status.patch \
    file://0004-rk3588-balena-bootcommand.patch \
    file://0005-rk3588-nvme-boot-env.patch \
    file://0006-rk3588-nvme-scan-pci-init.patch \
    file://0007-rk3588-sdhci-pulse-dt-resets.patch \
    file://0008-rk3588-sdhci-enable-clocks-hostctrl3.patch \
    file://0010-rk3588-sdhci-mux-shared-pads.patch \
    file://0011-setexpr-store-decimal-result.patch \
    file://0100-rkflash-sfc-unaligned-write.patch \
    file://0001-rockchip-use-python3-for-fit-generator.patch \
    file://0102-fit-restore-optee-node.patch \
    file://0103-spi-nor-ids-carry-zbit-entries.patch \
"

# Same Radxa tree for the RK3576 machine; each machine patches its own
# WORKDIR checkout, so the RK3588 sdhci patches (0007/0008/0010, which
# hard-code RK3588 CRU/GRF offsets) stay RK3588-only without a per-SoC
# tree split.  0100 fixes the SFC driver shared with the maskrom
# usbplug; 0101 widens the usbplug defconfig's SPI-flash vendor set
# (Seeed PR #10030: without it rkdevtool's "get capability" fails on
# boards with the new SPI flash during maskrom USB flashing).
SRC_URI:prepend:recomputer-rk3576-devkit = "${RADXA_UBOOT_SRCURI} "
SRC_URI:remove:recomputer-rk3576-devkit = "git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master;tag=v${PV} \
    git://source.denx.de/u-boot/u-boot.git;protocol=https;branch=master"
SRCREV:recomputer-rk3576-devkit = "${RADXA_UBOOT_SRCREV}"

SRC_URI:append:recomputer-rk3576-devkit = " \
    file://recomputer-rk3576-devkit_defconfig \
    file://rk3576-recomputer-rk3576-devkit.dts \
    file://rk3576-maskrom.ini \
    file://rk3576-usbplug-board.config \
    file://0002-rk3588-charge-animation-initialize-status.patch \
    file://0004-rk3576-balena-bootcommand.patch \
    file://0005-rk3576-usbplug-guard-scsi-bootdev.patch \
    file://0005-rk3588-nvme-boot-env.patch \
    file://0006-rk3588-nvme-scan-pci-init.patch \
    file://0011-setexpr-store-decimal-result.patch \
    file://0100-rkflash-sfc-unaligned-write.patch \
    file://0101-usbplug-defconfig-spi-flash-vendors.patch \
    file://0001-rockchip-use-python3-for-fit-generator.patch \
    file://0102-fit-restore-optee-node.patch \
    file://0103-spi-nor-ids-carry-zbit-entries.patch \
"

# meta-balena's env_resin.h drives the hostapp A/B rollback state machine
# with setexpr/test env scripting.  The 0011 patch makes this tree's setexpr
# store decimal results (env_set_hex "0x" output breaks cmd/test.c's base-10
# numeric parsing, so the rollback flip condition was always false).  With
# decimal values os_inc_bc_save exports "bootcount=N\n" (12 bytes for single
# digits), so files/env_resin.h in this layer retunes os_bc_wr_sz from 0xd
# (13, sized for "bootcount=0xN\n") to 0xc to keep the fatwrite payload
# tight; everything else in the file is identical to meta-balena-common's
# copy.  The FILESEXTRAPATHS prepend at the top of this file makes this
# layer's env_resin.h win the file://env_resin.h lookup from
# resin-u-boot.bbclass.

# Firmware and loader tooling come from the pinned official rkbin recipe;
# the Rockchip FIT generator consumes them from fixed file names in its
# working directory, so keep the source paths explicit to stay tied to
# the pinned rkbin deployment rather than a moving fetch.
BL31:recomputer-rk3588-devkit = "${DEPLOY_DIR_IMAGE}/bl31-rk3588.elf"
do_compile[depends] += "rockchip-rkbin:do_deploy"
RK_TEE:recomputer-rk3588-devkit = "${DEPLOY_DIR_IMAGE}/tee-rk3588.bin"
RK_BOOT_MERGER:recomputer-rk3588-devkit = "${DEPLOY_DIR_IMAGE}/boot_merger"
RK_USBPLUG:recomputer-rk3588-devkit = "${DEPLOY_DIR_IMAGE}/usbplug-rk3588.bin"
# The Wrynose U-Boot 2026.01 recipe adds a CVE backport for its pinned
# mainline tree. It targets files which do not exist in the Radxa vendor
# tree either, so applying it to this machine would make do_patch fail
# before configuration.  Revisit when the vendor tree picks up the
# matching fix.
SRC_URI:remove:recomputer-rk3588-devkit = " \
    file://CVE-2026-33243.patch \
"
# The Radxa tree carries the same license file as the SDK vendor tree.
LIC_FILES_CHKSUM:recomputer-rk3588-devkit = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

# The RK3576 machine builds from the same Radxa tree (see above);
# firmware and loader tooling likewise come from the pinned rkbin recipe.
BL31:recomputer-rk3576-devkit = "${DEPLOY_DIR_IMAGE}/bl31-rk3576.elf"
RK_TEE:recomputer-rk3576-devkit = "${DEPLOY_DIR_IMAGE}/tee-rk3576.bin"
RK_BOOT_MERGER:recomputer-rk3576-devkit = "${DEPLOY_DIR_IMAGE}/boot_merger"
# The maskrom loader's CODE472 usbplug is rebuilt from this tree (see
# do_compile) instead of using the rkbin prebuilt: the prebuilt (v1.04)
# runs UFS link training before serving USB (~20 s of UIC timeouts, which
# makes `upgrade_tool db` fail) and does not know the board NOR's ZBIT
# ZB25LQ128 JEDEC id.  Seeed's Armbian integration compiles the plug from
# source for the same reasons (RK_COMPILE_USBPLUG=yes).
RK_USBPLUG:recomputer-rk3576-devkit = "${WORKDIR}/usbplug-build/usbplug.bin"
# Same Wrynose CVE backport exception as the RK3588 machine: the patch
# targets mainline files absent from the Radxa vendor baseline.
SRC_URI:remove:recomputer-rk3576-devkit = " \
    file://CVE-2026-33243.patch \
"
LIC_FILES_CHKSUM:recomputer-rk3576-devkit = "file://Licenses/README;md5=a2c678cfd4a4d97135585cad908541c6"

do_configure:prepend:recomputer-rk3588-devkit() {
    # resin-u-boot injects these includes during do_configure, so remove
    # any prior generated copies first and make repeated configure runs
    # idempotent.
    sed -i '/^#include <env_resin.h>$/d; /^[[:space:]]*BALENA_ENV$/d' \
        ${S}/include/env_default.h
    sed -i '/^#include <config_resin.h>$/d' ${S}/include/config_defaults.h
    # resin-u-boot's production console silencing inserts a bare column-0
    # "return;" after each puts() definition, which is not idempotent
    # across repeated configure runs.  Strip stale copies (the class
    # re-applies the silencing itself for genuine production builds).
    sed -i '/^return;$/d' ${S}/common/console.c

    # Board defconfig (Seeed Armbian baseline for this tree + the
    # BalenaOS delta at the bottom of the file) and the board DTS land
    # in the tree.  dts/Makefile picks the DTS up through
    # CONFIG_DEFAULT_DEVICE_TREE; no arch/arm/dts/Makefile registration
    # is needed in this tree.
    install -Dm0644 ${UNPACKDIR}/recomputer-rk3588-devkit_defconfig \
        ${S}/configs/${UBOOT_MACHINE}
    install -Dm0644 ${UNPACKDIR}/rk3588-recomputer-rk3588-devkit.dts \
        ${S}/arch/arm/dts/rk3588-recomputer-rk3588-devkit.dts
    # The decimal setexpr makes os_inc_bc_save export "bootcount=N\n" (12
    # bytes for single digits), so retune the fatwrite size that the
    # environment carries for it.  resin-u-boot.bbclass copies env_resin.h
    # into the tree during do_generate_resin_uboot_configuration; patch
    # the in-tree copy as well so it cannot lag the layer override.
    sed -i 's/os_bc_wr_sz=0xd /os_bc_wr_sz=0xc /' ${S}/include/env_resin.h
}

do_configure:prepend:recomputer-rk3576-devkit() {
    # Same idempotent cleanup of resin-u-boot's injections as the RK3588
    # machine (env includes, config include, console silencing).
    sed -i '/^#include <env_resin.h>$/d; /^[[:space:]]*BALENA_ENV$/d' \
        ${S}/include/env_default.h
    sed -i '/^#include <config_resin.h>$/d' ${S}/include/config_defaults.h
    sed -i '/^return;$/d' ${S}/common/console.c

    # Board defconfig (Seeed Armbian baseline + BalenaOS delta) and the
    # board DTS; CONFIG_DEFAULT_DEVICE_TREE drives the build, no dts
    # Makefile registration needed.  No SPL_STACK_R relocation here
    # (unlike RK3588): the SoC gives SPL a 512 KiB SYS_MALLOC_F pool and
    # no SRAM layout conflict has been observed.  Revisit only if SPL
    # resets with "sys malloc pool space exhausted" during bring-up.
    install -Dm0644 ${UNPACKDIR}/recomputer-rk3576-devkit_defconfig \
        ${S}/configs/${UBOOT_MACHINE}
    install -Dm0644 ${UNPACKDIR}/rk3576-recomputer-rk3576-devkit.dts \
        ${S}/arch/arm/dts/rk3576-recomputer-rk3576-devkit.dts
    # Same decimal-bootcount retune of the fatwrite payload size as RK3588
    # (see the 0011 patch note above).
    sed -i 's/os_bc_wr_sz=0xd /os_bc_wr_sz=0xc /' ${S}/include/env_resin.h
}

# resin-u-boot's generic implementation still reads this file from WORKDIR.
# Wrynose places file:// inputs under UNPACKDIR, so provide the RK3588-specific
# implementation with the new path while retaining the same integration.
# Keep the explicit do_unpack dependency: the class's "after do_patch"
# ordering alone does not guarantee UNPACKDIR is populated for this task
# in every sstate/rebuild combination, and the copy of
# balena_check_crc32.c is read straight from UNPACKDIR.
python __anonymous() {
    deps = d.getVarFlag('do_inject_check_crc32_cmd', 'deps') or []
    if isinstance(deps, str):
        deps = deps.split()
    if 'do_unpack' not in deps:
        deps.append('do_unpack')
    d.setVarFlag('do_inject_check_crc32_cmd', 'deps', deps)
}
do_inject_check_crc32_cmd:recomputer-rk3588-devkit() {
    if ${@bb.utils.contains('OS_OVERLAP_CHECK_ENABLED', '1', 'true', 'false', d)}; then
        if ! grep -q -r "cmd_tbl_t" ${S}/cmd/ ; then
            sed -i 's/cmd_tbl_t/struct cmd_tbl/g' ${UNPACKDIR}/balena_check_crc32.c
        fi
        if [ ! -f ${S}/include/env.h ]; then
            sed -i 's/env.h/common.h/g' ${UNPACKDIR}/balena_check_crc32.c
            if ! grep -q env_get "${S}/include/common.h"; then
                sed -i 's/env_get/getenv/g' "${UNPACKDIR}/balena_check_crc32.c"
                sed -i 's/env_set/setenv/g' "${UNPACKDIR}/balena_check_crc32.c"
            fi
        fi
        cp ${UNPACKDIR}/balena_check_crc32.c ${S}/cmd/
        if ! grep -q "balena_check_crc32" ${S}/cmd/Makefile ; then
            cat >> ${S}/cmd/Makefile << EOF
ifndef CONFIG_SPL_BUILD
obj-y += balena_check_crc32.o
endif
EOF
        fi
    fi
}

# Same vendor-tree command injection for the RK3576 copy; the anonymous
# python block above already anchors this task after do_unpack for both
# machines.
do_inject_check_crc32_cmd:recomputer-rk3576-devkit() {
    if ${@bb.utils.contains('OS_OVERLAP_CHECK_ENABLED', '1', 'true', 'false', d)}; then
        if ! grep -q -r "cmd_tbl_t" ${S}/cmd/ ; then
            sed -i 's/cmd_tbl_t/struct cmd_tbl/g' ${UNPACKDIR}/balena_check_crc32.c
        fi
        if [ ! -f ${S}/include/env.h ]; then
            sed -i 's/env.h/common.h/g' ${UNPACKDIR}/balena_check_crc32.c
            if ! grep -q env_get "${S}/include/common.h"; then
                sed -i 's/env_get/getenv/g' "${UNPACKDIR}/balena_check_crc32.c"
                sed -i 's/env_set/setenv/g' "${UNPACKDIR}/balena_check_crc32.c"
            fi
        fi
        cp ${UNPACKDIR}/balena_check_crc32.c ${S}/cmd/
        if ! grep -q "balena_check_crc32" ${S}/cmd/Makefile ; then
            cat >> ${S}/cmd/Makefile << EOF
ifndef CONFIG_SPL_BUILD
obj-y += balena_check_crc32.o
endif
EOF
        fi
    fi
}

# The SDK RK3588 tree builds u-boot.bin and SPL as part of the normal `all`
# target, but the Rockchip boot flow consumes a FIT u-boot.itb plus an RKSD
# idbloader.img.  Generate both in the recipe work directory so the standard
# u-boot deploy task can publish them for Balena image assembly.
do_compile:append:recomputer-rk3588-devkit() {
    install -d ${B}/arch/arm/mach-rockchip
    ln -sf ${S}/arch/arm/mach-rockchip/fit_nodes.sh \
        ${B}/arch/arm/mach-rockchip/fit_nodes.sh
    ln -sf ${S}/arch/arm/mach-rockchip/fit_args.sh \
        ${B}/arch/arm/mach-rockchip/fit_args.sh
    ln -sf ${S}/arch/arm/mach-rockchip/decode_bl31.py \
        ${B}/arch/arm/mach-rockchip/decode_bl31.py

    # make_fit_atf.sh is a vendor script: decode_bl31.py looks specifically
    # for ./bl31.elf and fit_nodes.sh includes ./tee.bin.  BL31 alone is not
    # sufficient when the generator is called directly from this recipe.
    install -Dm0644 "${BL31}" ${B}/bl31.elf
    install -Dm0644 "${RK_TEE}" ${B}/tee.bin
    cd ${B}
    # RK3588 reserves the standard 0x08400000 offset from DRAM base 0 for
    # OP-TEE, matching the SDK make.sh default.
    srctree=. ${S}/arch/arm/mach-rockchip/make_fit_atf.sh \
        -t 0x08400000 > ${B}/u-boot.its
    ${B}/tools/mkimage -f ${B}/u-boot.its -E ${B}/u-boot.itb
    # The source-built tpl/u-boot-tpl.bin is a ~1KB version-string stub with
    # no DDR init.  Rockchip's own make.sh takes the TPL stage (FlashData)
    # from the rkbin DDR blob; use the same here or the bootrom jumps into a
    # stub that only prints a banner and hangs before DDR training.
    ${B}/tools/mkimage -n rk3588 -T rksd \
        -d ${DEPLOY_DIR_IMAGE}/ddr-rk3588.bin:${B}/spl/u-boot-spl.bin \
        ${B}/idbloader.img

    # Build the Rockchip Maskrom download loader from the same SDK blobs and
    # SPL used above.  This is deliberately separate from idbloader.img:
    # rkdeveloptool db consumes the boot_merger format, while SD/eMMC/SPI
    # boot consumes the RKSD idbloader format.
    install -Dm0644 ${UNPACKDIR}/rk3588-maskrom.ini ${B}/rk3588-maskrom.ini
    sed -i \
        -e "s|__DDR_PATH__|${DEPLOY_DIR_IMAGE}/ddr-rk3588.bin|g" \
        -e "s|__USBPLUG_PATH__|${RK_USBPLUG}|g" \
        -e "s|__SPL_PATH__|${B}/spl/u-boot-spl.bin|g" \
        ${B}/rk3588-maskrom.ini
    if [ ! -x "${RK_BOOT_MERGER}" ]; then
        bbfatal "Missing RK3588 boot_merger: ${RK_BOOT_MERGER}"
    fi
    (cd ${B} && "${RK_BOOT_MERGER}" ${B}/rk3588-maskrom.ini)
    install -Dm0644 ${B}/rk3588_spl_loader.bin ${B}/spl_loader_maskrom.bin

    # Assemble the SPI-NOR loader image using the same layout used by the
    # Seeed Armbian integration: GPT metadata plus idbloader at sector 64 and
    # U-Boot FIT at sector 16384.  Keep this as an independent deployable
    # artifact; the Balena system image still embeds the two raw components
    # at those offsets on its target disk.
    truncate -s 16M ${B}/rkspi_loader.img
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img mklabel gpt
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart idbloader 64 7167
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart vnvm 7168 7679
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart reserved_space 7680 8063
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart reserved1 8064 8127
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart uboot_env 8128 8191
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart reserved2 8192 16383
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart uboot 16384 32734
    dd if=${B}/idbloader.img of=${B}/rkspi_loader.img bs=512 seek=64 conv=notrunc
    dd if=${B}/u-boot.itb of=${B}/rkspi_loader.img bs=512 seek=16384 conv=notrunc
}

DEPENDS:append:recomputer-rk3588-devkit = " parted-native"

# Same artifact assembly for the RK3576 machine: FIT u-boot.itb, idbloader,
# maskrom download loader and the SPI-NOR image.  Key SoC differences from
# the RK3588 flow:
#   - The FIT TEE node uses the standard -t 0x08400000 offset; fit_args.sh
#     adds the SoC DRAM base itself (RK3576 SDRAM starts at 0x40000000, so
#     OP-TEE lands at 0x48400000; RK3588's DRAM base is 0 and the recipe
#     passed the absolute address there).
#   - The RK3576 boot ROM consumes a three-segment loader: boost (SRAM,
#     0x3FFC0000) + DDR init (0x3FF81000) + SPL.  The Radxa tree's mkimage
#     rksd type only understands two -d segments, so the idblock comes from
#     the same boot_merger run as the maskrom loader instead (CREATE_IDB
#     writes the storage-layout image; on the SDK tree the two paths were
#     verified byte-equivalent apart from header timestamps, and this is
#     also how Seeed's Armbian integration builds the rk3576 idbloader).
do_compile:append:recomputer-rk3576-devkit() {
    install -d ${B}/arch/arm/mach-rockchip
    ln -sf ${S}/arch/arm/mach-rockchip/fit_nodes.sh \
        ${B}/arch/arm/mach-rockchip/fit_nodes.sh
    ln -sf ${S}/arch/arm/mach-rockchip/fit_args.sh \
        ${B}/arch/arm/mach-rockchip/fit_args.sh
    ln -sf ${S}/arch/arm/mach-rockchip/decode_bl31.py \
        ${B}/arch/arm/mach-rockchip/decode_bl31.py

    install -Dm0644 "${BL31}" ${B}/bl31.elf
    install -Dm0644 "${RK_TEE}" ${B}/tee.bin
    cd ${B}
    srctree=. ${S}/arch/arm/mach-rockchip/make_fit_atf.sh \
        -t 0x08400000 > ${B}/u-boot.its
    ${B}/tools/mkimage -f ${B}/u-boot.its -E ${B}/u-boot.itb

    # Rebuild the maskrom usbplug (CODE472) in a separate output directory:
    # rockchip-usbplug_defconfig + configs/rk3576-usbplug.config, then the
    # board fragment (UFS off, ZBIT NOR on) appended so its values win the
    # olddefconfig pass.  ARCH=arm covers armv8 in this U-Boot generation.
    # The -Werror strip mirrors the Seeed Armbian build: the plug sources
    # predate the Wrynose host GCC.  sed is naturally idempotent, and the
    # relaxation also applies to this tree's main build (harmless).
    USBPLUG_BUILD=${WORKDIR}/usbplug-build
    mkdir -p ${USBPLUG_BUILD}
    oe_runmake -C ${S} O=${USBPLUG_BUILD} ARCH=arm rockchip-usbplug_defconfig
    cat ${S}/configs/rk3576-usbplug.config \
        ${UNPACKDIR}/rk3576-usbplug-board.config >> ${USBPLUG_BUILD}/.config
    oe_runmake -C ${S} O=${USBPLUG_BUILD} ARCH=arm olddefconfig
    # Strip the standalone -Werror (the plug sources predate the Wrynose
    # host GCC; same relaxation Seeed's build applies).  The patterns anchor
    # on end-of-line/trailing-space so -Werror=date-time survives intact.
    sed -i -e 's/[[:space:]]*-Werror[[:space:]]*$//' \
        -e 's/[[:space:]]*-Werror[[:space:]]/ /g' \
        ${S}/Makefile ${S}/scripts/Makefile.build
    oe_runmake -C ${S} O=${USBPLUG_BUILD} ARCH=arm
    [ -f "${RK_USBPLUG}" ] || bbfatal "usbplug build did not produce ${RK_USBPLUG}"

    # Maskrom download loader from the same blobs, following the official
    # RK3576MINIALL layout (boost/DDR/usbplug, NEWIDB + ALIGN=8).
    install -Dm0644 ${UNPACKDIR}/rk3576-maskrom.ini ${B}/rk3576-maskrom.ini
    sed -i \
        -e "s|__DDR_PATH__|${DEPLOY_DIR_IMAGE}/ddr-rk3576.bin|g" \
        -e "s|__USBPLUG_PATH__|${RK_USBPLUG}|g" \
        -e "s|__BOOST_PATH__|${DEPLOY_DIR_IMAGE}/boost-rk3576.bin|g" \
        -e "s|__SPL_PATH__|${B}/spl/u-boot-spl.bin|g" \
        ${B}/rk3576-maskrom.ini
    if [ ! -x "${RK_BOOT_MERGER}" ]; then
        bbfatal "Missing RK3576 boot_merger: ${RK_BOOT_MERGER}"
    fi
    (cd ${B} && "${RK_BOOT_MERGER}" ${B}/rk3576-maskrom.ini)
    install -Dm0644 ${B}/rk3576_spl_loader.bin ${B}/spl_loader_maskrom.bin
    # Storage-layout idblock from the same boot_merger run doubles as the
    # idbloader that gets written at sector 64 (see the function header).
    install -Dm0644 ${B}/rk3576_idblock.img ${B}/idbloader.img

    # SPI-NOR loader image with the same GPT layout used by the Seeed
    # Armbian integration (identical partition map for RK3576 and RK3588):
    # idbloader at sector 64 and the U-Boot FIT at sector 16384.
    truncate -s 16M ${B}/rkspi_loader.img
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img mklabel gpt
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart idbloader 64 7167
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart vnvm 7168 7679
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart reserved_space 7680 8063
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart reserved1 8064 8127
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart uboot_env 8128 8191
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart reserved2 8192 16383
    ${STAGING_SBINDIR_NATIVE}/parted -s ${B}/rkspi_loader.img unit s mkpart uboot 16384 32734
    dd if=${B}/idbloader.img of=${B}/rkspi_loader.img bs=512 seek=64 conv=notrunc
    dd if=${B}/u-boot.itb of=${B}/rkspi_loader.img bs=512 seek=16384 conv=notrunc
}

DEPENDS:append:recomputer-rk3576-devkit = " parted-native"

# partition 1 is used for idbloader.img,partition 2 for u-boot.itb, partition 3 is left empty for the new BSP but we keep it so we are backward compatible
BALENA_BOOT_PART:rockpi-4b-rk3399 = "4"
BALENA_DEFAULT_ROOT_PART:rockpi-4b-rk3399 = "5"

BALENA_UBOOT_DEVICES = "0 1"

# Create extlinux.conf for the internal image; this file will be stored in the rootfs' boot directory

# The former Radxa meta-rockchip layer used to enable extlinux generation for
# its machines; the official SDK layer does not, so enable it here explicitly
# or the u-boot-extlinux package referenced by the images is not produced.
UBOOT_EXTLINUX = "1"
UBOOT_EXTLINUX_LABELS = "balenaOS"
UBOOT_EXTLINUX_ROOT = "${resin_kernel_root}"
UBOOT_EXTLINUX_KERNEL_ARGS = "${os_cmdline}"

# Seeed reComputer RK3588 DevKit. The boot partition follows two raw loader
# entries in the Balena GPT image, so boot/rootA are partitions 3/4.
BALENA_BOOT_PART:recomputer-rk3588-devkit = "3"
BALENA_DEFAULT_ROOT_PART:recomputer-rk3588-devkit = "4"
BALENA_UBOOT_DEVICES:recomputer-rk3588-devkit = "0 1"
# The eMMC on early boards may not enumerate; the NVMe SSD is the usable
# internal storage, so the resin flasher/image flag scan must cover it in
# addition to mmc.  bootcmd runs "nvme scan" before resin_set_kernel_root
# (see 0005-rk3588-nvme-boot-env.patch) so this scan can find the device.
BALENA_UBOOT_DEVICE_TYPES:recomputer-rk3588-devkit = "mmc nvme"

# Seeed reComputer RK3576 DevKit.  Same layout: two raw loader entries, so
# boot/rootA are partitions 3/4.  Aliases in rk3576-u-boot.dtsi map mmc0 to
# eMMC (sdhci) and mmc1 to the SD card.  The flasher media can be an
# external SD card or NVMe SSD, hence the mmc+nvme scan set.
BALENA_BOOT_PART:recomputer-rk3576-devkit = "3"
BALENA_DEFAULT_ROOT_PART:recomputer-rk3576-devkit = "4"
BALENA_UBOOT_DEVICES:recomputer-rk3576-devkit = "0 1"
BALENA_UBOOT_DEVICE_TYPES:recomputer-rk3576-devkit = "mmc nvme"

UBOOT_EXTLINUX_LABELS:recomputer-rk3576-devkit = "balenaOS"
UBOOT_EXTLINUX_ROOT:recomputer-rk3576-devkit = "${resin_kernel_root}"
UBOOT_EXTLINUX_KERNEL_ARGS:recomputer-rk3576-devkit = "${os_cmdline}"

# do_deploy must stay stamp-based.  A nostamp deploy forces a partial rerun on
# no-op rebuilds: balena-image's do_image_balenaos_img (which embeds the raw
# loaders) reruns with a fresh DATETIME while the sibling docker-image task
# stays cached, and do_image_size_check then fails with FileNotFoundError on
# the new IMAGE_NAME.  To force the recipe to pick up source or layer-file
# edits, run `bitbake -c clean u-boot` instead of forcing redeploy here.

# Create extlinux.conf for the flasher image; this file will be stored in the boot partition
do_deploy:append() {
    KERNEL_CMDLINE_ARGS_FLASHER="console=tty1 console=ttyFIQ0,1500000n8 rw root=LABEL=flash-rootA rootfstype=ext4 rootwait flasher"

    mkdir -p ${DEPLOY_DIR_IMAGE}/extlinux || true
    cat >${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf_flasher <<EOF
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /$(echo "${KERNEL_DEVICETREE}" | cut -d '/' -f 2)
    APPEND ${KERNEL_CMDLINE_ARGS_FLASHER}
EOF

}

do_deploy:append:recomputer-rk3588-devkit() {
    KERNEL_CMDLINE_ARGS_FLASHER="console=tty1 console=ttyFIQ0,1500000n8 rw root=LABEL=flash-rootA rootfstype=ext4 rootwait flasher"

    install -d ${DEPLOY_DIR_IMAGE}/extlinux
    cat > ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf_flasher <<EOF
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /rk3588-recomputer-rk3588-devkit.dtb
    APPEND ${KERNEL_CMDLINE_ARGS_FLASHER}
EOF

    # Runtime version: the APPEND placeholders are expanded by the
    # U-Boot environment (resin_kernel_root / os_cmdline) at boot time,
    # matching the u-boot-extlinux package's rootfs copy.  The SFC
    # (SPI-NOR) controller shares its m0 pads with the eMMC; letting its
    # driver probe steals the pads back and kills the eMMC root
    # mid-boot, so both the SFC and the NOR-backed vendor storage are
    # kept out of the runtime.
    cat > ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf <<EOF
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /rk3588-recomputer-rk3588-devkit.dtb
    APPEND \${resin_kernel_root} \${os_cmdline} console=ttyFIQ0,1500000n8 rootfstype=ext4 rootwait initcall_blacklist=rockchip_sfc_driver_init,vendor_storage_init
EOF

    install -m0644 ${B}/rk3588_spl_loader.bin \
        ${DEPLOY_DIR_IMAGE}/rk3588_spl_loader.bin
    install -m0644 ${B}/spl_loader_maskrom.bin \
        ${DEPLOY_DIR_IMAGE}/spl_loader_maskrom.bin
    install -m0644 ${B}/rkspi_loader.img \
        ${DEPLOY_DIR_IMAGE}/rkspi_loader.img
    # The image recipes and BALENA_BOOT_PARTITION_FILES consume the raw
    # Rockchip boot chain from the deploy directory (idbloader at sector 64,
    # u-boot.itb at sector 16384); deploy both unversioned as well.
    install -m0644 ${B}/idbloader.img \
        ${DEPLOY_DIR_IMAGE}/idbloader.img
    install -m0644 ${B}/u-boot.itb \
        ${DEPLOY_DIR_IMAGE}/u-boot.itb
}

do_deploy:append:recomputer-rk3576-devkit() {
    KERNEL_CMDLINE_ARGS_FLASHER="console=tty1 console=ttyFIQ0,1500000n8 rw root=LABEL=flash-rootA rootfstype=ext4 rootwait flasher"

    install -d ${DEPLOY_DIR_IMAGE}/extlinux
    cat > ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf_flasher <<EOF
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /rk3576-recomputer-rk3576-devkit.dtb
    APPEND ${KERNEL_CMDLINE_ARGS_FLASHER}
EOF

    # Runtime extlinux: APPEND placeholders are expanded by the U-Boot
    # environment (resin_kernel_root / os_cmdline) at boot time.  The
    # SFC/eMMC initcall blacklist is deliberately NOT carried over from
    # RK3588: on RK3576 the FSPI0 and eMMC pads are independent, and the
    # SPI NOR stays available at runtime until board validation proves
    # otherwise.
    cat > ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf <<EOF
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /rk3576-recomputer-rk3576-devkit.dtb
    APPEND \${resin_kernel_root} \${os_cmdline} console=ttyFIQ0,1500000n8 rootfstype=ext4 rootwait
EOF

    install -m0644 ${B}/rk3576_spl_loader.bin \
        ${DEPLOY_DIR_IMAGE}/rk3576_spl_loader.bin
    install -m0644 ${B}/spl_loader_maskrom.bin \
        ${DEPLOY_DIR_IMAGE}/spl_loader_maskrom.bin
    install -m0644 ${B}/rkspi_loader.img \
        ${DEPLOY_DIR_IMAGE}/rkspi_loader.img
    # Raw Rockchip boot chain for Balena image assembly (idbloader at
    # sector 64, u-boot.itb at sector 16384); deploy unversioned as well.
    install -m0644 ${B}/idbloader.img \
        ${DEPLOY_DIR_IMAGE}/idbloader.img
    install -m0644 ${B}/u-boot.itb \
        ${DEPLOY_DIR_IMAGE}/u-boot.itb
}
