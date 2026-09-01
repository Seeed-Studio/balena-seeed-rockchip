# Installs the build host's SSH public key into /root/.ssh/authorized_keys
# so key-based ssh/scp over the gadget link (ssh -p 22222 root@10.55.0.2)
# works immediately after every re-flash, with zero on-board setup.
#
# Development images only (OS_DEVELOPMENT = 1): production images must not
# ship a trust anchor for a specific developer machine.  The package stays
# in IMAGE_INSTALL unconditionally and simply installs nothing when the
# gate is off.
SUMMARY = "Build-host SSH public key for root (development images)"
LICENSE = "CLOSED"
SRC_URI = "file://authorized_keys"

S = "${UNPACKDIR}"

ALLOW_EMPTY:${PN} = "1"

do_install() {
    if [ "${OS_DEVELOPMENT}" != "1" ]; then
        exit 0
    fi
    install -d ${D}/root/.ssh
    install -m 0600 ${S}/authorized_keys ${D}/root/.ssh/authorized_keys
}

FILES:${PN} = "/root/.ssh/authorized_keys"
