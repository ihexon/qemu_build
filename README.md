# qemu_build

Portable, headless QEMU 11.0.0 builds for libvirt-managed Linux guests.

This project builds a small QEMU distribution focused on `qemu-system-aarch64`
and `qemu-img`. It targets ARM `virt` machines, common virtio devices, vhost-user
virtiofs integration, and headless server workloads.

Release artifacts are built for:

- macOS aarch64
- Linux x86_64
- Linux aarch64

The build intentionally omits desktop/display features, bundled firmware blobs,
guest-agent binaries, and storage/display integrations that are not needed for
the intended headless libvirt use case.

Build scripts live in `scripts/`, the device profile lives in `configs/`, and
GitHub Actions publishes release archives from tagged builds.
