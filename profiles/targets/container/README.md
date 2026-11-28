# StormByte container profiles

The `StormByte/glibc/Container` and `StormByte/musl/Container` profiles use
their respective internal StormByte bases and share the container target. They
retain the compiler toolchain, security, optimizations and StormByte functions,
without including the host package set or enabling the StageManager dependency
of `StormByte-meta`. They also remove `e2fsprogs` from Gentoo's `@system`.

Containers use the host kernel. These profiles disable the default
`dist-kernel`, `kernel-install` and `grub` USE flags; they do not prevent an
explicitly selected package or dependency from installing a kernel or other
host-oriented packages.

Removing a package from `@system` does not uninstall it from an existing stage:
packages explicitly selected in `@world` or required by other packages remain.
Review the selected packages and dependencies when building the stage. The
inherited `-march=native` setting targets the build host's CPU.
