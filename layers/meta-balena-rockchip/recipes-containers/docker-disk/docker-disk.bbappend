do_compile:prepend() {
	# The helper daemon only pulls an image and creates a data filesystem; it
	# does not need to provide container network forwarding.
	sed -i 's/ -b none --experimental/ -b none --iptables=false --experimental/' \
		${UNPACKDIR}/entry.sh
}
