#!/usr/bin/env bash
set -euo pipefail

VIRTIOFSD_COMMIT="${VIRTIOFSD_COMMIT:-acb3d506a9f1b256fff7327023df85570caf1e75}"
VIRTIOFSD_REF="${VIRTIOFSD_COMMIT:0:12}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.cache/work}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

OS_NAME="$(uname -s)"
MACHINE="$(uname -m)"
case "$OS_NAME" in
  Linux) OS_TAG="linux" ;;
  *) echo "virtiofsd is only built for Linux hosts" >&2; exit 1 ;;
esac
case "$MACHINE" in
  arm64|aarch64) ARCH_TAG="aarch64" ;;
  x86_64|amd64) ARCH_TAG="x86_64" ;;
  *) ARCH_TAG="$MACHINE" ;;
esac

SOURCE_DIR="$WORK_DIR/virtiofsd-$VIRTIOFSD_COMMIT"
PACKAGE_NAME="virtiofsd-$VIRTIOFSD_REF"
PREFIX="$WORK_DIR/install/$PACKAGE_NAME-$OS_TAG-$ARCH_TAG"
PACKAGE_DIR="$DIST_DIR/$PACKAGE_NAME-$OS_TAG-$ARCH_TAG-portable"

install_dependencies() {
  if command -v apk >/dev/null 2>&1; then
    apk add --no-cache \
      build-base ca-certificates curl file git libcap-ng-dev libcap-ng-static \
      libseccomp-dev libseccomp-static linux-headers pkgconf
  elif command -v apt-get >/dev/null 2>&1; then
    local apt=(apt-get)
    if [[ "${EUID:-$(id -u)}" != "0" ]]; then
      apt=(sudo apt-get)
    fi
    "${apt[@]}" update
    "${apt[@]}" install -y \
      build-essential ca-certificates curl file git libcap-ng-dev \
      libseccomp-dev pkg-config
  else
    echo "Unsupported Linux package manager; install virtiofsd build dependencies manually" >&2
    exit 1
  fi

  if ! command -v rustup >/dev/null 2>&1; then
    curl -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh
    sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain stable --no-modify-path
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
  rustup toolchain install stable --profile minimal
  rustup default stable
  rustc --version
  cargo --version
}

prepare_source() {
  rm -rf "$SOURCE_DIR" "$PREFIX" "$PACKAGE_DIR"
  mkdir -p "$WORK_DIR" "$DIST_DIR"
  git clone https://gitlab.com/virtio-fs/virtiofsd.git "$SOURCE_DIR"
  git -C "$SOURCE_DIR" checkout "$VIRTIOFSD_COMMIT"
}

build_and_install() {
  cargo build --manifest-path "$SOURCE_DIR/Cargo.toml" --release --locked -j "$JOBS"

  mkdir -p "$PREFIX/bin" "$PREFIX/share/doc/virtiofsd"
  cp "$SOURCE_DIR/target/release/virtiofsd" "$PREFIX/bin/virtiofsd"
  cp "$SOURCE_DIR/LICENSE-APACHE" "$PREFIX/share/doc/virtiofsd/"
  cp "$SOURCE_DIR/LICENSE-BSD-3-Clause" "$PREFIX/share/doc/virtiofsd/"
}

copy_package() {
  mkdir -p "$PACKAGE_DIR"
  cp -R "$PREFIX/." "$PACKAGE_DIR/"
  strip --strip-unneeded "$PACKAGE_DIR/bin/virtiofsd" 2>/dev/null || true
}

write_notes() {
  cat > "$PACKAGE_DIR/BUILD-NOTES.txt" <<EOF
virtiofsd $VIRTIOFSD_REF $OS_TAG $ARCH_TAG portable build
==========================================================

Source:
- https://gitlab.com/virtio-fs/virtiofsd
- commit $VIRTIOFSD_COMMIT

Build profile:
- Linux host only
- official Rust toolchain from rustup
- native $ARCH_TAG build

Notes:
- This is packaged separately from QEMU.
- The upstream 50-virtiofsd.json descriptor is not bundled because it hard-codes
  /usr/libexec/virtiofsd instead of this portable package path.
EOF
}

verify_package() {
  "$PACKAGE_DIR/bin/virtiofsd" --version | tee "$PACKAGE_DIR/virtiofsd-version.txt"
  file "$PACKAGE_DIR/bin/virtiofsd" | tee "$PACKAGE_DIR/file-virtiofsd.txt"
  ldd "$PACKAGE_DIR/bin/virtiofsd" | tee "$PACKAGE_DIR/ldd-virtiofsd.txt" || true
}

archive_package() {
  local archive="$PACKAGE_DIR.tar.gz"
  tar -C "$DIST_DIR" -czf "$archive" "$(basename "$PACKAGE_DIR")"
  echo "Created $archive"
}

main() {
  install_dependencies
  prepare_source
  build_and_install
  copy_package
  write_notes
  verify_package
  archive_package
}

main "$@"
