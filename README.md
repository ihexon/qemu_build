# qemu_build

Portable, headless QEMU 11.0.0 builds for libvirt-managed Linux guests.

The build targets `qemu-system-aarch64` and keeps `qemu-img`. It is intended for
headless server workloads rather than desktop/display use.

## Supported build hosts

- macOS aarch64: GitHub Actions `macos-14`
- Linux x86_64: GitHub Actions `ubuntu-24.04` with an Alpine container
- Linux aarch64: GitHub Actions `ubuntu-24.04-arm` with an Alpine container

GitHub documents these runner labels in its hosted runner reference:
<https://docs.github.com/en/actions/reference/github-hosted-runners-reference>

## Included QEMU features

- `aarch64-softmmu` only
- ARM `virt` machine
- HVF on macOS
- KVM on Linux aarch64
- TCG everywhere
- `virtio-blk`, `virtio-net`, `virtio-pci`
- `virtio-rng`, `virtio-balloon`
- `virtio-scsi`
- `virtio-serial`, `virtserialport`
- `vhost-user-fs` for virtiofs
- `qemu-img`

## Trimmed features

- VNC, Cocoa, SDL, GTK, OpenGL, SPICE
- slirp and macOS vmnet
- QEMU firmware/blob installation
- host `qemu-ga`
- TPM, 9p virtfs, Xen, RDMA
- USB redirection, libusb, smartcard, U2F, CanoKey
- audio backends
- old image formats: bochs, cloop, dmg, qcow1, qed, vdi, vhdx, vmdk, vpc, parallels
- remote storage client libraries: rbd, glusterfs, libiscsi, libnfs, libssh, curl
- virgl/rutabaga and other display-oriented components

## Portability model

macOS does not support a normal fully static QEMU Mach-O build in this setup; a
direct `--static` build fails during link because Darwin has no suitable
`crt0.o` path for that model. The macOS build therefore prefers Homebrew static
libraries where available, then bundles any remaining non-system dylibs and
rewrites install names to `@loader_path` relative paths. macOS system frameworks
and `/usr/lib` libraries remain dynamic.

Linux builds run inside Alpine containers and are configured with `--static`.
This avoids glibc static-link NSS/runtime warnings for functions such as
`getpwnam_r` and `getpwuid_r`. Linux release binaries are stripped with
`strip --strip-unneeded`.

## Guest-agent and virtiofs notes

This package does not include a host-side `qemu-ga` binary. For Linux guests,
install `qemu-guest-agent` inside the guest. The QEMU-side channel required by
libvirt is present through `virtio-serial` and `virtserialport`.

This package also does not include `virtiofsd`. If libvirt uses virtiofs, provide
a compatible `virtiofsd` separately and point libvirt at it.

## Local build

Install dependencies:

```sh
./scripts/install-deps.sh
```

Build and package:

```sh
./scripts/build-qemu.sh
```

Artifacts are written to `dist/`.

## Release

Pushing a tag beginning with `v` runs the full matrix and publishes a GitHub
Release containing all produced archives:

```sh
git tag v11.0.0-1
git push origin main v11.0.0-1
```
