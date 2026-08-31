# write internal balenaOS image to the eMMC
INTERNAL_DEVICE_KERNEL = "mmcblk0"

# Keep the stock flasher behaviour of powering off after the install.  The
# U-Boot bootcmd boots flasher media exclusively whenever the flasher flag
# file is detected (see 0005-rk3588-nvme-boot-env.patch), so an automatic
# reboot with the install medium still attached would loop straight back
# into the flasher and re-flash forever.  Power off, remove the medium,
# then power on to boot the freshly installed eMMC runtime.
