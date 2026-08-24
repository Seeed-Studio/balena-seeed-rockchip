SUMMARY = "Seeed RK3588 vendor Linux kernel"
DESCRIPTION = "Linux 6.1 vendor kernel used by the reComputer RK3588 DevKit."
SECTION = "kernel"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

inherit kernel
inherit kernel-yocto

COMPATIBLE_MACHINE = "^recomputer-rk3588-devkit$"

KBRANCH = "rk-6.1-rkr5.1"
SRC_URI = " \
    git://github.com/armbian/linux-rockchip.git;protocol=https;branch=${KBRANCH} \
    file://balena-rk3588.cfg \
"
SRCREV = "c6157104418d012823413c02f9222f3fe123dd25"

S = "${WORKDIR}/git"
PV = "6.1+git${SRCPV}"
# The vendor branch reports its patchlevel (currently 6.1.115) from the
# source Makefile while this recipe intentionally keeps the stable 6.1+git PV.
KERNEL_VERSION_SANITY_SKIP = "1"

# The generic vendor defconfig enables drivers for many unrelated SoCs.  The
# Rockchip defconfig keeps the module set aligned with this 6.1 vendor tree
# and avoids compiling incompatible DRM drivers from other platforms.
KBUILD_DEFCONFIG = "rockchip_linux_defconfig"
KERNEL_IMAGETYPE = "Image"
KERNEL_DEVICETREE = "rockchip/rk3588-recomputer-rk3588-devkit.dtb"
# The recipe uses kernel-yocto so the .cfg in SRC_URI is merged through the
# standard kernel metadata queue. meta-rockchip also adds a kmeta feature for
# its linux-yocto recipes; this independent vendor tree does not carry that
# kmeta repository, so do not request the dangling feature here.
KERNEL_FEATURES:remove:recomputer-rk3588-devkit = "bsp/rockchip/remove-non-rockchip-arch-arm64.scc"

# The source branch already contains the board DTS and its camera/include
# files. Keeping the source pinned here makes the first Balena bring-up
# independent from the dirty Armbian cache worktree.
