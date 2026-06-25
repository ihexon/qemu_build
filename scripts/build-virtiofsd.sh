#!/usr/bin/env bash
set -euo pipefail
VIRTIOFSD_COMMIT="${VIRTIOFSD_COMMIT:-acb3d506a9f1b256fff7327023df85570caf1e75}"
VIRTIOFSD_REF="${VIRTIOFSD_COMMIT:0:12}"
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-stable}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.cache/work}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
CARGO_HOME="${CARGO_HOME:-$ROOT_DIR/.cache/cargo}"
RUSTUP_HOME="${RUSTUP_HOME:-$ROOT_DIR/.cache/rustup}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

export CARGO_HOME RUSTUP_HOME
export PATH="$CARGO_HOME/bin:$PATH"

OS_NAME="$(uname -s)"
MACHINE="$(uname -m)"
case "$OS_NAME" in
    Linux) OS_TAG="linux" ;;
    *)
        echo "virtiofsd is only built for Linux hosts" >&2
        exit 1
        ;;
esac
case "$MACHINE" in
    arm64 | aarch64) ARCH_TAG="aarch64" ;;
    x86_64 | amd64) ARCH_TAG="x86_64" ;;
    *) ARCH_TAG="$MACHINE" ;;
esac

SOURCE_DIR="$WORK_DIR/virtiofsd-$VIRTIOFSD_COMMIT"
PACKAGE_NAME="virtiofsd-$VIRTIOFSD_REF"
PREFIX="$WORK_DIR/install/$PACKAGE_NAME-$OS_TAG-$ARCH_TAG"
ARCHIVE="$DIST_DIR/$PACKAGE_NAME-$OS_TAG-$ARCH_TAG-portable.tar.gz"

install_dependencies() {
    if command -v apk >/dev/null 2>&1; then
        if [[ -f /etc/apk/repositories ]]; then
            sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories
        fi
        apk add --no-cache \
            build-base ca-certificates curl file git libcap-ng-dev libcap-ng-static \
            libseccomp-dev libseccomp-static linux-headers pkgconf
    else
        echo "Unsupported Linux package manager; install virtiofsd build dependencies manually" >&2
        exit 1
    fi
}

install_rust_toolchain() {
    if command -v rustup >/dev/null 2>&1; then
        rustup toolchain install "$RUST_TOOLCHAIN" --profile minimal --no-self-update
    else
        curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | \
            sh -s -- -y --profile minimal --default-toolchain "$RUST_TOOLCHAIN"
    fi
    rustup default "$RUST_TOOLCHAIN"
    rustc --version
    cargo --version
}

prepare_source() {
    rm -rf "$SOURCE_DIR" "$PREFIX" "$ARCHIVE"
    mkdir -p "$WORK_DIR" "$DIST_DIR"
    git clone https://gitlab.com/virtio-fs/virtiofsd.git "$SOURCE_DIR"
    git -C "$SOURCE_DIR" checkout "$VIRTIOFSD_COMMIT"
}

build_and_install() {
    # Official musl Rust targets already default to a static CRT. Keeping
    # crt-static out of global RUSTFLAGS avoids breaking proc-macro crates.
    LIBSECCOMP_LINK_TYPE=static \
        LIBSECCOMP_LIB_PATH=/usr/lib \
        LIBCAPNG_LINK_TYPE=static \
        LIBCAPNG_LIB_PATH=/usr/lib \
        RUSTFLAGS="-C link-arg=-static-libgcc" \
        cargo rustc --manifest-path "$SOURCE_DIR/Cargo.toml" \
        --release --locked -j "$JOBS" --bin virtiofsd

    mkdir -p "$PREFIX"
    cp -v "$SOURCE_DIR/target/release/virtiofsd" "$PREFIX/virtiofsd"
    strip --strip-unneeded "$PREFIX/virtiofsd" 2>/dev/null || true
}

verify_package() {
    local file_output

    "$PREFIX/virtiofsd" --version
    file_output="$(file "$PREFIX/virtiofsd")"
    echo "$file_output"
    case "$file_output" in
        *"statically linked"* | *"static-pie linked"*) ;;
        *)
            echo "virtiofsd is not fully statically linked" >&2
            exit 1
            ;;
    esac
    if command -v readelf >/dev/null 2>&1 && readelf -l "$PREFIX/virtiofsd" | grep -q INTERP; then
        echo "virtiofsd has a dynamic interpreter" >&2
        exit 1
    fi
    ldd "$PREFIX/virtiofsd" || true
}

archive_package() {
    tar -C "$PREFIX" -czf "$ARCHIVE" virtiofsd
    echo "Created $ARCHIVE"
}

main() {
    install_dependencies
    install_rust_toolchain
    prepare_source
    build_and_install
    verify_package
    archive_package
}

main "$@"
