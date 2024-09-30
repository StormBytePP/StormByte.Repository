if [ -z "$EMERGE_VERBOSE" ]; then
    export CMAKE_VERBOSE=OFF
    export CUDA_VERBOSE=OFF
    export EXTRA_EMAKE="V=0"
    export KERNEL_VERBOSE=OFF
    export MESON_VERBOSE=OFF
    export NINJA_VERBOSE=OFF
    export PORTAGE_QUIET=1
    export WAF_VERBOSE=OFF
else
    export CMAKE_VERBOSE=ON
    export CUDA_VERBOSE=ON
    export EXTRA_EMAKE="V=1"
    export KERNEL_VERBOSE=ON
    export MESON_VERBOSE=ON
    export NINJA_VERBOSE=ON
    export PORTAGE_QUIET=0
    export WAF_VERBOSE=ON
fi