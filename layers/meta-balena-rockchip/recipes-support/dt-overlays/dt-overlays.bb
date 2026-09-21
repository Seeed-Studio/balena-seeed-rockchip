# Host OS helper for the board device tree overlays: it lists what the image
# ships in /boot and maintains the `fdtoverlays` variable of
# /mnt/boot/extra_uEnv.txt, which U-Boot imports into its environment before
# it boots the kernel (see the 0013-pxe patch and the UBOOT_EXTLINUX_
# FDTOVERLAYS assignment in the u-boot bbappend).
#
# The overlays themselves are built by the BSP layer (KERNEL_DEVICETREE in
# the machine confs).  The package is only pulled into the balena-image, not
# into the flasher, which has nothing to select.
SUMMARY = "Select the device tree overlays applied at boot"
DESCRIPTION = "Lists the board device tree overlays shipped in /boot and \
writes the fdtoverlays list consumed by the board's U-Boot."
LICENSE = "CLOSED"

SRC_URI = " \
    file://dt-overlays \
    file://overlays.list \
"

S = "${UNPACKDIR}"

inherit allarch

RDEPENDS:${PN} = "bash coreutils"

do_install() {
    install -d ${D}${sbindir} ${D}${datadir}/dt-overlays
    install -m 0755 ${S}/dt-overlays ${D}${sbindir}/dt-overlays
    install -m 0644 ${S}/overlays.list ${D}${datadir}/dt-overlays/overlays.list
}

FILES:${PN} = " \
    ${sbindir}/dt-overlays \
    ${datadir}/dt-overlays \
"