# Copyright (C) 2024, Rockchip Electronics Co., Ltd
# Released under the MIT license (see COPYING.MIT for the terms)

require recipes-kernel/linux-libc-headers/linux-libc-headers.inc

inherit auto-patch

inherit local-git

SRCREV = "31ba856fa45c27046ebdc111a9b62f9c21103e85"
# The SDK pins a historical commit which is no longer advertised under the
# old date-based branch name. Fetch by immutable revision instead of requiring
# a branch that disappeared from the upstream mirror.
SRC_URI = " \
	git://github.com/JeffyCN/mirrors.git;protocol=https;nobranch=1; \
"

S = "${UNPACKDIR}/linux-libc-headers-${PV}"

LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"
