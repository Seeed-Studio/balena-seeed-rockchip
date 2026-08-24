FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Balena's Scarthgap rust layer pins LLVM 13 (rust-llvm 1.62.0).  GCC 15
# stopped providing several fixed-width integer declarations as incidental
# transitive includes, so carry the upstream LLVM fixes needed by this older
# source on newer build hosts.
SRC_URI:append = " \
    file://0036-Add-cstdint-to-SmallVector-101761.patch;striplevel=2 \
    file://0037-Include-cstdint-in-AMDGPUMCTargetDesc-101766.patch;striplevel=2 \
    file://0038-Add-missing-include-to-X86MCTargetDesc.h-123320.patch;striplevel=2 \
"
