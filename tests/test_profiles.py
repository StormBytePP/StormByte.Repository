import os
from pathlib import Path
import unittest

import portage
from portage.package.ebuild.config import config


ROOT = Path(__file__).resolve().parents[1]
LEAVES = (
    "glibc",
    "glibc/Container",
    "glibc/desktop",
    "glibc/desktop/gnome",
    "glibc/desktop/plasma",
    "musl",
    "musl/Container",
    "musl/server",
)


class ProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        gentoo = portage.settings.repositories["gentoo"].location
        env = dict(os.environ)
        env["PORTAGE_REPOSITORIES"] = (
            f"[DEFAULT]\nmain-repo = gentoo\n[gentoo]\nlocation = {gentoo}\n"
            f"[StormByte]\nlocation = {ROOT}\nmasters = gentoo\n"
        )
        cls.profiles = {
            leaf: config(
                config_profile_path=str(ROOT / "profiles" / "StormByte" / leaf),
                env=env,
                local_config=False,
            )
            for leaf in LEAVES
        }

    def test_selectable_profiles_and_hooks(self):
        descriptors = {
            line.split()[1]
            for line in (ROOT / "profiles" / "profiles.desc").read_text().splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        self.assertEqual(descriptors, {f"StormByte/{leaf}" for leaf in LEAVES})
        for leaf, settings in self.profiles.items():
            with self.subTest(profile=leaf):
                self.assertTrue(settings.profiles)
                local_profiles = [
                    profile for profile in settings.profiles
                    if profile.startswith(str(ROOT / "profiles") + os.sep)
                ]
                self.assertEqual(len(local_profiles), len(set(local_profiles)))
                settings.setcpv(
                    "llvm-runtimes/libcxx-22.1.6",
                    mydb={
                        "EAPI": "8",
                        "KEYWORDS": "~amd64",
                        "SLOT": "0",
                        "IUSE": "clang static-libs",
                        "repository": "gentoo",
                    },
                )
                hooks = list(settings._pbashrc)
                for feature in ("debug", "bugfixes"):
                    hook = str(ROOT / "profiles" / "features" / feature / "profile.bashrc")
                    self.assertEqual(hooks.count(hook), 1)
                self.assertTrue(hooks[-1].endswith("/features/bugfixes/profile.bashrc"))

    def test_container_excludes_host_extras(self):
        host_packages = {
            "*app-benchmarks/hyperfine",
            "*app-containers/docker",
            "*app-containers/docker-cli",
            "*app-containers/podman",
            "*app-crypt/sbsigntools",
            "*dev-debug/ddd",
            "*dev-debug/gdb",
            "*dev-debug/strace",
            "*dev-debug/valgrind",
            "*llvm-core/lldb",
            "*sys-apps/dmidecode",
            "*sys-block/io-scheduler-udev-rules",
            "*sys-boot/grub",
            "*sys-boot/mokutil",
            "*sys-boot/shim",
            "*sys-fs/btrfs-progs",
            "*sys-fs/e2fsprogs",
        }
        for libc in ("glibc", "musl"):
            with self.subTest(libc=libc):
                host = self.profiles[libc]
                container = self.profiles[f"{libc}/Container"]
                self.assertTrue(host_packages <= set(host.packages))
                self.assertFalse(host_packages & set(container.packages))
                self.assertIn("*sys-libs/StormByte-functions", container.packages)
                self.assertEqual(container["CC"], "clang-22")
                self.assertFalse(
                    {"dist-kernel", "kernel-install", "grub"} & set(container["USE"].split())
                )
                self.assertTrue(
                    {"lto", "pgo", "hardened", "verify-provenance"}
                    <= set(container["USE"].split())
                )
                for settings, expected in ((host, True), (container, False)):
                    settings.setcpv(
                        "sys-apps/StormByte-meta-3.0.0-r1",
                        mydb={
                            "EAPI": "8",
                            "KEYWORDS": "~amd64",
                            "SLOT": "0",
                            "IUSE": "portageconfig stagemanager utils videoconvert",
                            "repository": "StormByte",
                        },
                    )
                    self.assertEqual("stagemanager" in settings["PORTAGE_USE"].split(), expected)

    def test_dependency_masks(self):
        for leaf, settings in self.profiles.items():
            with self.subTest(profile=leaf):
                masks = settings._mask_manager
                self.assertIsNone(
                    masks.getMaskAtom("llvm-runtimes/clang-runtime-22-r1", "22", "gentoo")
                )
                self.assertIsNotNone(
                    masks.getMaskAtom("llvm-runtimes/clang-runtime-23-r2", "23", "gentoo")
                )
                self.assertIsNotNone(
                    masks.getMaskAtom("llvm-core/clang-23-r1", "23", "gentoo")
                )
                self.assertIsNotNone(
                    masks.getMaskAtom("llvm-runtimes/compiler-rt-23-r1", "23", "gentoo")
                )


if __name__ == "__main__":
    unittest.main()
