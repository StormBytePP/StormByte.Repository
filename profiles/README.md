# StormByte profiles

The selectable profiles remain under `StormByte/` and are listed in
`profiles.desc`. Each is composed in order from an internal libc base, optional
host and target profiles, and finally `features/bugfixes`.

- `base/` combines the Gentoo libc profile with common StormByte features.
- `features/` contains reusable policies, including host packages, debugging
  tools, LLVM, optimizations, security and shared bugfixes.
- `targets/` contains role-specific settings and packages.

Selectable profiles compose internal profiles directly rather than inheriting
other selectable profiles, so profile hooks and final bugfixes are applied once.
The Gentoo profiles may themselves share ancestors.

Run `python -m unittest discover -s tests` on a Gentoo system with Portage and
the Gentoo repository configured to validate the profile composition.
