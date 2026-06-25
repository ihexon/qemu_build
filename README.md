# qemu_build

Portable, headless QEMU 11.0.0 builds for libvirt-managed Linux guests.

This project builds small QEMU distributions focused on the host platform's
matching system emulator and core QEMU tools. It targets same-architecture
headless Linux guests, virtio devices, vhost-user virtiofs integration, and
server workloads.

Release artifacts are built for:

- macOS aarch64
- Linux x86_64
- Linux aarch64

Linux x86_64 builds produce `qemu-x86_64-headless-linux` packages with
`qemu-system-x86_64`, including x86 `microvm` machine support.

All packages include `qemu-img`, `qemu-io`, `qemu-nbd`, and
`qemu-storage-daemon`. Linux packages also include `qemu-ga` for
same-architecture Linux guests and `qemu-pr-helper` for shared SCSI LUN
persistent-reservation setups. Linux packages also include `virtiofsd` built
from `gitlab.com/virtio-fs/virtiofsd`.

All packages include matching-architecture EDK2 UEFI firmware copied from
QEMU's upstream `pc-bios` blobs. The `*-vars.fd` file is a template; copy it per
VM before using it as a writable varstore.

The build intentionally omits desktop/display features, unrelated firmware
blobs, cross-architecture emulators, and storage/display integrations that are
not needed for the intended headless libvirt use case.

Build scripts live in `scripts/`, the device profile lives in `configs/`, and
GitHub Actions publishes release archives from tagged builds.
