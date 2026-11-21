# newminhh Distribution & Boot Integration

This directory contains service scripts, initramfs/initrd hooks, and distribution packaging files to automatically integrate `newminhh` into Linux operating systems.

## 1. Directory Structure

```
distribution/
├── service/
│   ├── binfmt-helper.sh          # Universal shell helper to mount and register/unregister binfmt_misc
│   ├── systemd/
│   │   ├── newminhh.conf         # /usr/lib/binfmt.d/ rule for systemd-binfmt.service
│   │   └── newminhh-binfmt.service# Standalone systemd oneshot fallback unit
│   ├── openrc/
│   │   └── newminhh-binfmt       # OpenRC init.d service script
│   ├── runit/
│   │   ├── run                   # runit core service script
│   │   └── finish                # runit unregister cleanup script
│   ├── s6/
│   │   ├── type                  # s6-rc oneshot definition
│   │   └── up                    # execlineb script to register binfmt_misc
│   └── busybox/
│       └── S05newminhh-binfmt    # SysV / busybox init.d script (runlevel S / sysinit)
├── init-tools/
│   ├── dracut/
│   │   └── 95newminhh/
│   │       ├── module-setup.sh   # Dracut module: installs runner, x32 libs, and hook
│   │       └── newminhh-binfmt-initrd.sh # Pre-pivot hook (registers binfmt with 'F' flag)
│   ├── mkinitcpio/
│   │   ├── install_newminhh      # Arch mkinitcpio build hook
│   │   └── hook_newminhh         # Arch mkinitcpio runtime hook
│   ├── mkinitfs/
│   │   ├── newminhh.initd        # Alpine mkinitfs early init hook
│   │   └── newminhh.files        # Alpine mkinitfs binary and library manifest
│   └── initramfs-tools/
│       ├── hook_newminhh         # Debian initramfs-tools copy hook
│       └── script_newminhh       # Debian initramfs-tools init-bottom hook
└── distro/
    ├── debian/                   # Debian packaging (debhelper, control, rules, postinst)
    ├── arch/                     # Arch Linux PKGBUILD & .install
    └── alpine/                   # Alpine Linux APKBUILD & trigger
```

## 2. Kernel `binfmt_misc` Registration Specification

All service managers and initramfs hooks register the following rule:

```
:newminhh-i386:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/newminhh-run:POCF
```

### Match Fields:
- **Magic**: `\x7fELF\x01\x01\x01...` matches ELF 32-bit (`\x01`), Little Endian (`\x01`), Version 1 (`\x01`), Executable/Shared (`\x02\x00`), `e_machine = EM_386` (`\x03\x00`).
- **Interpreter**: `/usr/bin/newminhh-run`.

### Flags:
- **`P` (Preserve argv[0])**: Leaves `argv[0]` intact so the guest application receives its authentic process name.
- **`O` (Open Binary / AT_EXECFD)**: Linux kernel opens the binary file descriptor before invoking the interpreter.
- **`C` (Credentials)**: Preserves setuid/setgid execution policies.
- **`F` (Fix Binary)**: **Crucial for container / chroot / initrd handoff.** The kernel opens the `/usr/bin/newminhh-run` binary at registration time and pins its executable node in memory. Even after `switch_root` / `pivot_root` or inside isolated chroots where `/usr/bin/newminhh-run` is not physically present on disk, the kernel can execute i386 binaries seamlessly.

## 3. Initrd / Early Boot Integration

When `newminhh` is bundled into the initramfs via Dracut, mkinitcpio, mkinitfs, or initramfs-tools:
1. The x32 dynamic linker (`ld-linux-x32.so.2` or `ld-musl-x32.so.1`), core runtime libraries, and `newminhh-run` are copied into the initrd image.
2. The runtime hook runs before `switch_root` / handoff to the real rootfs.
3. Because the registration uses the `F` (Fix Binary) flag, non-x32 native i386 binaries can execute during early rootfs discovery, storage driver initialization, and all subsequent stages.
