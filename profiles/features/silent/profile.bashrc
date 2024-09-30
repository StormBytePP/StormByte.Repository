if [ -z "$EMERGE_VERBOSE" ]; then
    CMAKE_VERBOSE=OFF
    CUDA_VERBOSE=OFF
    EXTRA_EMAKE="V=0"
    KERNEL_VERBOSE=OFF
    MESON_VERBOSE=OFF
    NINJA_VERBOSE=OFF
    PORTAGE_QUIET=1
    WAF_VERBOSE=OFF
else
    CMAKE_VERBOSE=ON
    CUDA_VERBOSE=ON
    EXTRA_EMAKE="V=1"
    KERNEL_VERBOSE=ON
    MESON_VERBOSE=ON
    NINJA_VERBOSE=ON
    PORTAGE_QUIET=0
    WAF_VERBOSE=ON
fi