# profile.bashrc — musl profile
# Force mimalloc on the most allocation-heavy toolchain packages

case "${CATEGORY}/${PN}" in
    llvm-core/llvm|llvm-core/clang|llvm-core/lld|llvm-runtimes/libcxx|llvm-runtimes/libcxxabi|dev-lang/rust)
        # Link the final binaries/libraries against mimalloc
        export LDFLAGS="${LDFLAGS} -lmimalloc"

        # Use mimalloc already while building these packages
        if [[ -e /usr/lib/libmimalloc.so ]]; then
            export LD_PRELOAD="/usr/lib/libmimalloc.so${LD_PRELOAD:+:${LD_PRELOAD}}"
        fi
        ;;

    dev-db/sqlite|dev-lang/python)
        # Python has TLS conflicts with mimalloc during build
        # Clear LD_PRELOAD to avoid the "initial-exec TLS" error
        unset LD_PRELOAD
        ;;
esac