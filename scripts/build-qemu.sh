#!/usr/bin/env bash
set -euo pipefail

QEMU_VERSION="${QEMU_VERSION:-11.0.0}"
QEMU_SHA256="${QEMU_SHA256:-c04ca36012653f32d11c674d370cf52a710e7d3f18c2d8b63e4932052a4854d6}"
TARGET_LIST="${TARGET_LIST:-aarch64-softmmu}"
DEVICE_PROFILE="${DEVICE_PROFILE:-headless-linux}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.cache/work}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$ROOT_DIR/.cache/downloads}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}"

OS_NAME="$(uname -s)"
MACHINE="$(uname -m)"
case "$OS_NAME" in
  Darwin) OS_TAG="macos" ;;
  Linux) OS_TAG="linux" ;;
  *) echo "Unsupported host OS: $OS_NAME" >&2; exit 1 ;;
esac
case "$MACHINE" in
  arm64|aarch64) ARCH_TAG="aarch64" ;;
  x86_64|amd64) ARCH_TAG="x86_64" ;;
  *) ARCH_TAG="$MACHINE" ;;
esac

SOURCE_ARCHIVE="$DOWNLOAD_DIR/qemu-$QEMU_VERSION.tar.xz"
SOURCE_DIR="$WORK_DIR/qemu-$QEMU_VERSION"
BUILD_DIR="$SOURCE_DIR/build"
PREFIX="$WORK_DIR/install/qemu-$QEMU_VERSION-$OS_TAG-$ARCH_TAG"
PACKAGE_DIR="$DIST_DIR/qemu-$QEMU_VERSION-$OS_TAG-$ARCH_TAG"

download_source() {
  mkdir -p "$DOWNLOAD_DIR"
  if [[ ! -f "$SOURCE_ARCHIVE" ]]; then
    curl -fsSL "https://download.qemu.org/qemu-$QEMU_VERSION.tar.xz" -o "$SOURCE_ARCHIVE"
  fi

  if command -v shasum >/dev/null 2>&1; then
    echo "$QEMU_SHA256  $SOURCE_ARCHIVE" | shasum -a 256 -c -
  else
    echo "$QEMU_SHA256  $SOURCE_ARCHIVE" | sha256sum -c -
  fi
}

prepare_source() {
  rm -rf "$SOURCE_DIR" "$PREFIX" "$PACKAGE_DIR"
  mkdir -p "$WORK_DIR" "$DIST_DIR"
  tar -C "$WORK_DIR" -xf "$SOURCE_ARCHIVE"
  mkdir -p "$SOURCE_DIR/configs/devices/aarch64-softmmu"
  cp "$ROOT_DIR/configs/devices/aarch64-softmmu/$DEVICE_PROFILE.mak" \
    "$SOURCE_DIR/configs/devices/aarch64-softmmu/$DEVICE_PROFILE.mak"
}

configure_qemu() {
  local python_bin
  python_bin="$(command -v python3)"

  local args=(
    "--python=$python_bin"
    "--prefix=$PREFIX"
    "--target-list=$TARGET_LIST"
    "--with-devices-aarch64=$DEVICE_PROFILE"
    "--without-default-devices"
    "--without-default-features"
    "--enable-system"
    "--disable-user"
    "--enable-tools"
    "--disable-docs"
    "--disable-install-blobs"
    "--disable-guest-agent"
    "--enable-tcg"
    "--enable-fdt=internal"
    "--enable-vhost-user"
    "--disable-vhost-kernel"
    "--disable-vhost-net"
    "--disable-vhost-crypto"
    "--disable-vhost-vdpa"
    "--disable-cocoa"
    "--disable-sdl"
    "--disable-gtk"
    "--disable-vnc"
    "--disable-slirp"
    "--disable-vmnet"
    "--disable-pixman"
    "--disable-opengl"
    "--disable-spice"
    "--disable-libusb"
    "--disable-usb-redir"
    "--disable-tpm"
    "--disable-virtfs"
    "--disable-xen"
    "--disable-rdma"
    "--disable-curl"
    "--disable-bzip2"
    "--disable-lzfse"
    "--disable-zstd"
    "--disable-lzo"
    "--disable-snappy"
    "--disable-bochs"
    "--disable-cloop"
    "--disable-dmg"
    "--disable-qcow1"
    "--disable-qed"
    "--disable-vdi"
    "--disable-vhdx"
    "--disable-vmdk"
    "--disable-vpc"
    "--disable-parallels"
    "--disable-gnutls"
    "--disable-gcrypt"
    "--disable-nettle"
    "--disable-capstone"
    "--disable-rutabaga-gfx"
    "--disable-virglrenderer"
    "--disable-rbd"
    "--disable-glusterfs"
    "--disable-libiscsi"
    "--disable-libnfs"
    "--disable-libssh"
    "--disable-smartcard"
    "--disable-u2f"
    "--disable-canokey"
    "--disable-coreaudio"
    "--disable-pa"
    "--disable-pipewire"
    "--disable-jack"
    "--disable-stack-protector"
    "--disable-werror"
  )

  if [[ "$OS_TAG" == "macos" ]]; then
    args+=("--enable-hvf")
  fi

  if [[ "$OS_TAG" == "linux" ]]; then
    args+=("--static")
    if [[ "$ARCH_TAG" == "aarch64" ]]; then
      args+=("--enable-kvm")
    fi
  fi

  (cd "$SOURCE_DIR" && ./configure "${args[@]}")
}

build_and_install() {
  ninja -C "$BUILD_DIR" -j "$JOBS" qemu-system-aarch64 qemu-img
  DESTDIR= ninja -C "$BUILD_DIR" install
}

copy_base_package() {
  mkdir -p "$PACKAGE_DIR/bin" "$PACKAGE_DIR/share/qemu"
  cp "$PREFIX/bin/qemu-system-aarch64" "$PACKAGE_DIR/bin/"
  cp "$PREFIX/bin/qemu-img" "$PACKAGE_DIR/bin/"
  if [[ "$OS_TAG" == "linux" ]]; then
    strip --strip-unneeded "$PACKAGE_DIR/bin/qemu-system-aarch64" "$PACKAGE_DIR/bin/qemu-img"
  fi
  if [[ -f "$PREFIX/share/qemu/trace-events-all" ]]; then
    cp "$PREFIX/share/qemu/trace-events-all" "$PACKAGE_DIR/share/qemu/"
  fi
}

is_system_macho_dep() {
  [[ "$1" == /usr/lib/* || "$1" == /System/Library/* ]]
}

bundle_macos_dylibs() {
  local item dep base rel
  mkdir -p "$PACKAGE_DIR/lib"

  local queue=("$PACKAGE_DIR/bin/qemu-system-aarch64" "$PACKAGE_DIR/bin/qemu-img")
  local seen=""

  while ((${#queue[@]})); do
    item="${queue[0]}"
    queue=("${queue[@]:1}")
    [[ "$seen" == *"|$item|"* ]] && continue
    seen="$seen|$item|"

    while read -r dep; do
      [[ -z "$dep" ]] && continue
      [[ "$dep" == @* ]] && continue
      is_system_macho_dep "$dep" && continue
      [[ ! -f "$dep" ]] && continue

      base="$(basename "$dep")"
      if [[ ! -f "$PACKAGE_DIR/lib/$base" ]]; then
        cp "$dep" "$PACKAGE_DIR/lib/$base"
        chmod u+w "$PACKAGE_DIR/lib/$base"
        queue+=("$PACKAGE_DIR/lib/$base")
      fi

      if [[ "$item" == "$PACKAGE_DIR/bin/"* ]]; then
        rel="@loader_path/../lib/$base"
      else
        rel="@loader_path/$base"
      fi
      install_name_tool -change "$dep" "$rel" "$item" 2>/dev/null || true
    done < <(otool -L "$item" | awk 'NR > 1 { print $1 }')

    if [[ "$item" == "$PACKAGE_DIR/lib/"* ]]; then
      install_name_tool -id "@rpath/$(basename "$item")" "$item" 2>/dev/null || true
    fi
  done
}

sign_macos_package() {
  local entitlements="$SOURCE_DIR/accel/hvf/entitlements.plist"
  while IFS= read -r -d '' dylib; do
    codesign --force --sign - "$dylib"
  done < <(find "$PACKAGE_DIR/lib" -type f -name '*.dylib' -print0 2>/dev/null)
  codesign --force --sign - "$PACKAGE_DIR/bin/qemu-img"
  if [[ -f "$entitlements" ]]; then
    codesign --force --sign - --entitlements "$entitlements" "$PACKAGE_DIR/bin/qemu-system-aarch64"
  else
    codesign --force --sign - "$PACKAGE_DIR/bin/qemu-system-aarch64"
  fi
}

write_notes() {
  cat > "$PACKAGE_DIR/BUILD-NOTES.txt" <<EOF
QEMU $QEMU_VERSION $OS_TAG $ARCH_TAG portable headless build
=============================================================

Target:
- qemu-system-aarch64
- qemu-img

Build profile:
- aarch64-softmmu only
- ARM virt machine
- headless Linux/libvirt oriented
- HVF on macOS, KVM on Linux aarch64, TCG everywhere
- virtio-blk, virtio-net, virtio-pci, virtio-rng, virtio-balloon
- virtio-scsi, virtio-serial, virtserialport
- vhost-user-fs for virtiofs

Trimmed:
- VNC, Cocoa, SDL, GTK, OpenGL, SPICE
- slirp, vmnet
- QEMU firmware/blob installation
- host qemu-ga binary
- 9p virtfs, TPM, Xen, RDMA, USB redirection, audio backends
- old image formats: bochs, cloop, dmg, qcow1, qed, vdi, vhdx, vmdk, vpc, parallels
- remote storage libraries: rbd, glusterfs, libiscsi, libnfs, libssh, curl

Portability:
- macOS: dynamic Mach-O with bundled non-system dylibs and @loader_path paths.
- Linux: configured with --static.
- Linux release binaries are stripped with strip --strip-unneeded.
- System libraries/frameworks may still be required where the OS does not support
  a fully static executable model.

Notes:
- No upstream QEMU C source patches are applied.
- The build copies in one QEMU device profile:
  configs/devices/aarch64-softmmu/headless-linux.mak
- Linux guests should install qemu-guest-agent inside the guest. This package
  provides the QEMU-side virtio-serial channel, not a guest agent binary.
- virtiofsd is not included; provide a compatible virtiofsd separately.
EOF
}

verify_package() {
  "$PACKAGE_DIR/bin/qemu-system-aarch64" --version
  "$PACKAGE_DIR/bin/qemu-img" --version
  "$PACKAGE_DIR/bin/qemu-system-aarch64" -accel help
  "$PACKAGE_DIR/bin/qemu-system-aarch64" -display help
  "$PACKAGE_DIR/bin/qemu-system-aarch64" -machine virt -device help | tee "$PACKAGE_DIR/device-help.txt"
  "$PACKAGE_DIR/bin/qemu-system-aarch64" -machine virt -netdev help | tee "$PACKAGE_DIR/netdev-help.txt"
  "$PACKAGE_DIR/bin/qemu-img" --help | tee "$PACKAGE_DIR/qemu-img-help.txt"

  grep -q 'virtio-blk-pci' "$PACKAGE_DIR/device-help.txt"
  grep -q 'virtio-net-pci' "$PACKAGE_DIR/device-help.txt"
  grep -q 'virtio-rng-pci' "$PACKAGE_DIR/device-help.txt"
  grep -q 'virtio-balloon-pci' "$PACKAGE_DIR/device-help.txt"
  grep -q 'virtio-serial-pci' "$PACKAGE_DIR/device-help.txt"
  grep -q 'virtserialport' "$PACKAGE_DIR/device-help.txt"
  grep -q 'vhost-user-fs-pci' "$PACKAGE_DIR/device-help.txt"
  grep -q 'vhost-user' "$PACKAGE_DIR/netdev-help.txt"

  if [[ "$OS_TAG" == "macos" ]]; then
    otool -L "$PACKAGE_DIR/bin/qemu-system-aarch64" | tee "$PACKAGE_DIR/otool-qemu-system-aarch64.txt"
    codesign --verify --verbose=2 "$PACKAGE_DIR/bin/qemu-system-aarch64" "$PACKAGE_DIR/bin/qemu-img"
  else
    file "$PACKAGE_DIR/bin/qemu-system-aarch64" | tee "$PACKAGE_DIR/file-qemu-system-aarch64.txt"
    ldd "$PACKAGE_DIR/bin/qemu-system-aarch64" | tee "$PACKAGE_DIR/ldd-qemu-system-aarch64.txt" || true
  fi
}

archive_package() {
  local archive="$DIST_DIR/qemu-$QEMU_VERSION-$OS_TAG-$ARCH_TAG.tar.gz"
  tar -C "$DIST_DIR" -czf "$archive" "$(basename "$PACKAGE_DIR")"
  echo "Created $archive"
}

main() {
  download_source
  prepare_source
  configure_qemu
  build_and_install
  copy_base_package
  if [[ "$OS_TAG" == "macos" ]]; then
    bundle_macos_dylibs
    sign_macos_package
  fi
  write_notes
  verify_package
  archive_package
}

main "$@"
