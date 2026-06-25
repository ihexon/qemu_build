#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
  Darwin)
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew is required on macOS" >&2
      exit 1
    fi
    brew update
    brew install glib ninja pkg-config python
    ;;
  Linux)
    if command -v apk >/dev/null 2>&1; then
      apk add --no-cache \
        bash bison build-base ca-certificates curl file flex gettext-dev \
        gettext-static git glib-dev glib-static libffi-dev eudev-dev \
        linux-headers meson ninja pcre2-dev pkgconf python3 \
        xz zlib-dev zlib-static
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y \
        build-essential ca-certificates curl file flex bison \
        gettext libffi-dev libglib2.0-dev libpcre2-dev libudev-dev \
        meson ninja-build pkg-config python3 python3-venv zlib1g-dev
    else
      echo "Unsupported Linux package manager; install QEMU build dependencies manually" >&2
      exit 1
    fi
    ;;
  *)
    echo "Unsupported host OS: $(uname -s)" >&2
    exit 1
    ;;
esac
