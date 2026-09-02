# Installs the build host's SSH public key into /root/.ssh/authorized_keys_local
# so key-based ssh/scp over the gadget link (ssh -p 22222 root@10.55.0.2)
# works immediately after every re-flash, with zero on-board setup.
#
# Development images only (OS_DEVELOPMENT = 1): production images must not
# ship a trust anchor for a specific developer machine.  The package stays
# in IMAGE_INSTALL unconditionally and simply installs nothing when the
# gate is off.
#
# NOTE: the file MUST be authorized_keys_local, not authorized_keys.
# sshd@.service runs ssh_keys_merger (ExecStartPre) before every connection,
# which regenerates authorized_keys as the concatenation of
# authorized_keys_remote + authorized_keys_local.  Shipping authorized_keys
# directly gets shadowed on the first connection after boot (the merger
# writes an empty file over it in the overlay upper layer, permanently).
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
    install -m 0600 ${S}/authorized_keys ${D}/root/.ssh/authorized_keys_local
}

FILES:${PN} = "/root/.ssh/authorized_keys_local"
