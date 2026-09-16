FILESEXTRAPATHS:prepend := "${THISDIR}/files:${SEEED_ROCKCHIP_LAYERDIR}/recipes-bsp/u-boot/files:"

inherit resin-u-boot

SRC_URI:append = " \
    file://0001-balena-uboot-environment.patch \
    file://0005-balena-setexpr-decimal-result.patch \
"
SRC_URI:append:rk3588 = " \
    file://0003-balena-rk3588-bootcommand.patch \
    file://0004-balena-nvme-boot-environment.patch \
"
SRC_URI:append:rk3576 = " \
    file://0002-balena-rk3576-bootcommand.patch \
    file://0004-balena-nvme-boot-environment.patch \
"

SRC_URI:append:rk3588 = " file://balena-rk3588.cfg"
SRC_URI:append:rk3576 = " file://balena-rk3576.cfg"
UBOOT_EXTRA_CONFIG = "${UNPACKDIR}/balena-${RK_SOC_FAMILY}.cfg"

# resin-u-boot adds generated environment files during configure. Remove stale
# copies before it runs so repeated configure executions remain idempotent.
do_configure:prepend() {
    sed -i '/^#include <env_resin.h>$/d; /^[[:space:]]*BALENA_ENV$/d' \
        ${S}/include/env_default.h
    sed -i '/^#include <config_resin.h>$/d' ${S}/include/config_defaults.h
    sed -i '/^return;$/d' ${S}/common/console.c
    sed -i 's/os_bc_wr_sz=0xd /os_bc_wr_sz=0xc /' ${S}/include/env_resin.h
}

python __anonymous() {
    deps = d.getVarFlag('do_inject_check_crc32_cmd', 'deps') or []
    if isinstance(deps, str):
        deps = deps.split()
    if 'do_unpack' not in deps:
        deps.append('do_unpack')
    d.setVarFlag('do_inject_check_crc32_cmd', 'deps', deps)
}

do_inject_check_crc32_cmd() {
    if ${@bb.utils.contains('OS_OVERLAP_CHECK_ENABLED', '1', 'true', 'false', d)}; then
        if ! grep -q -r "cmd_tbl_t" ${S}/cmd/; then
            sed -i 's/cmd_tbl_t/struct cmd_tbl/g' ${UNPACKDIR}/balena_check_crc32.c
        fi
        if [ ! -f ${S}/include/env.h ]; then
            sed -i 's/env.h/common.h/g' ${UNPACKDIR}/balena_check_crc32.c
            if ! grep -q env_get "${S}/include/common.h"; then
                sed -i 's/env_get/getenv/g' ${UNPACKDIR}/balena_check_crc32.c
                sed -i 's/env_set/setenv/g' ${UNPACKDIR}/balena_check_crc32.c
            fi
        fi
        cp ${UNPACKDIR}/balena_check_crc32.c ${S}/cmd/
        if ! grep -q "balena_check_crc32" ${S}/cmd/Makefile; then
            cat >> ${S}/cmd/Makefile << EOF2
ifndef CONFIG_SPL_BUILD
obj-y += balena_check_crc32.o
endif
EOF2
        fi
    fi
}

BALENA_UBOOT_DEVICES = "0 1"
UBOOT_EXTLINUX = "1"
UBOOT_EXTLINUX_LABELS = "balenaOS"
UBOOT_EXTLINUX_ROOT = "${resin_kernel_root}"
UBOOT_EXTLINUX_KERNEL_ARGS = "${os_cmdline}"
# The vendor U-Boot extlinux scan resolves FDTDIR entries only against
# vendor subdirectories (../rockchip/*.dtb), but the rootfs installs the
# dtb flat in /boot.  With the balena devplist patch the scan targets the
# root partition, whose OE-generated extlinux.conf would fail with
# "File not found ... Skipping" right after loading the kernel.  Point
# at the dtb file explicitly instead.
UBOOT_EXTLINUX_FDT = "../${@d.getVar('KERNEL_DEVICETREE').split()[0].split('/')[-1]}"
BALENA_BOOT_PART = "3"
BALENA_DEFAULT_ROOT_PART = "4"
BALENA_UBOOT_DEVICE_TYPES = "mmc nvme"

do_deploy:append() {
    KERNEL_CMDLINE_ARGS_FLASHER="console=tty1 console=ttyFIQ0,1500000n8 rw root=LABEL=flash-rootA rootfstype=ext4 rootwait flasher"

    install -d ${DEPLOY_DIR_IMAGE}/extlinux
    cat > ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf_flasher <<EOF2
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /$(echo "${KERNEL_DEVICETREE}" | cut -d '/' -f 2)
    APPEND ${KERNEL_CMDLINE_ARGS_FLASHER}
EOF2
}

do_deploy:append:rk3588() {
    cat > ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf <<EOF2
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /rk3588-recomputer-rk3588-devkit.dtb
    APPEND \${resin_kernel_root} \${os_cmdline} console=ttyFIQ0,1500000n8 rootfstype=ext4 rootwait initcall_blacklist=rockchip_sfc_driver_init,vendor_storage_init
EOF2
}

do_deploy:append:rk3576() {
    cat > ${DEPLOY_DIR_IMAGE}/extlinux/extlinux.conf <<EOF2
default balenaOS

LABEL balenaOS
    KERNEL /${KERNEL_IMAGETYPE}
    FDT /rk3576-recomputer-rk3576-devkit.dtb
    APPEND \${resin_kernel_root} \${os_cmdline} console=ttyFIQ0,1500000n8 rootfstype=ext4 rootwait
EOF2
}
