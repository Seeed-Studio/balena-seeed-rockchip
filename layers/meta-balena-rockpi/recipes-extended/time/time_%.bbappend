FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# GNU time 1.9 declares signal handlers without an argument.  GCC 15 with
# current glibc headers rejects that incompatible function-pointer type.
SRC_URI:append = " file://0001-fix-signal-handler-type-for-modern-glibc.patch"
