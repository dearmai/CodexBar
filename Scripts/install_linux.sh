#!/usr/bin/env bash

# Build and install the Linux desktop, the CodexBar CLI, and the launcher entry for this user.
# Arguments are forwarded to Integrations/Linux/install.py (--no-autostart, --omarchy, --provider).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BUILD_DIR="${CODEXBAR_LINUX_BUILD_DIR:-$ROOT_DIR/.local/linux-build}"
CLI_DIR="$PREFIX/lib/codexbar"
CONFIGURATION="${CONFIGURATION:-release}"

# A Homebrew-on-Linux toolchain resolves its own linker and libgomp, which target a newer
# glibc than Enterprise Linux 9 provides; the desktop then fails to link. Keep it out of the
# C++ build without disturbing the Swift toolchain the caller put on PATH.
system_path() {
    local entry result=""
    while IFS= read -r entry; do
        case "$entry" in
            "" | *linuxbrew* | */homebrew/*) continue ;;
        esac
        result="${result:+$result:}$entry"
    done <<<"${PATH//:/$'\n'}"
    printf '%s' "$result"
}

require() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Missing %s. %s\n' "$1" "$2" >&2
        exit 1
    }
}

# Swift is rarely on PATH on Enterprise Linux 9 because there is no distro package; the
# toolchain is unpacked by hand or by swiftly. Look where it usually lands before giving up.
ensure_swift() {
    command -v swift >/dev/null 2>&1 && return 0
    local candidate
    for candidate in \
        "${SWIFT_TOOLCHAIN:+$SWIFT_TOOLCHAIN/usr/bin}" \
        "${SWIFT_HOME:+$SWIFT_HOME/usr/bin}" \
        "$HOME/.local/share/swiftly/bin" \
        /opt/swift/usr/bin \
        /usr/local/swift/usr/bin \
        /usr/libexec/swift/bin; do
        [[ -n "$candidate" && -x "$candidate/swift" ]] || continue
        PATH="$candidate:$PATH"
        export PATH
        printf '==> Using the Swift toolchain at %s\n' "$candidate"
        return 0
    done
    cat >&2 <<'EOF'
Missing swift. Install a Swift 6.2+ toolchain, then rerun.

  Enterprise Linux 9 has no Swift package. Install the official UBI 9 build:
    curl -fL https://download.swift.org/swift-6.2-release/ubi9/swift-6.2-RELEASE/swift-6.2-RELEASE-ubi9.tar.gz \
      | sudo tar xz -C /opt --one-top-level=swift --strip-components=1

  This script finds a toolchain at /opt/swift automatically. To use one elsewhere,
  put it on PATH or set SWIFT_TOOLCHAIN to the directory holding usr/bin/swift.
EOF
    exit 1
}

find_qmake() {
    local candidate
    for candidate in "${QMAKE:-}" qmake6 qmake-qt6 /usr/lib64/qt6/bin/qmake /usr/lib/qt6/bin/qmake; do
        [[ -n "$candidate" ]] || continue
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
        if [[ -x "$candidate" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    printf 'Missing qmake6. Install Qt 6 development packages (Enterprise Linux 9: enable EPEL, then qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtsvg-devel qt6-qttools-devel).\n' >&2
    exit 1
}

ensure_swift
require python3 "Install python3."
qmake="$(find_qmake)"

printf '==> Building the CodexBar CLI (%s)\n' "$CONFIGURATION"
swift build -c "$CONFIGURATION" --product CodexBarCLI
bin_dir="$(swift build -c "$CONFIGURATION" --show-bin-path)"
[[ -f "$bin_dir/CodexBarCLI" ]] || {
    printf 'SwiftPM reported no CodexBarCLI at %s\n' "$bin_dir" >&2
    exit 1
}

# Match the release archive layout: the executable, its resource bundle, and the codexbar name.
resources=""
for candidate in "$bin_dir/CodexBar_CodexBarCore.bundle" "$bin_dir/CodexBar_CodexBarCore.resources"; do
    [[ -d "$candidate" ]] && {
        resources="$candidate"
        break
    }
done
[[ -n "$resources" ]] || {
    printf 'Missing CodexBarCore resource bundle in %s\n' "$bin_dir" >&2
    exit 1
}

printf '==> Installing the CLI to %s\n' "$CLI_DIR"
install -d "$CLI_DIR" "$PREFIX/bin"
install -m 0755 "$bin_dir/CodexBarCLI" "$CLI_DIR/CodexBarCLI"
rm -rf "$CLI_DIR/CodexBar_CodexBarCore.bundle"
cp -R "$resources" "$CLI_DIR/CodexBar_CodexBarCore.bundle"
ln -sfn CodexBarCLI "$CLI_DIR/codexbar"
ln -sfn "$CLI_DIR/codexbar" "$PREFIX/bin/codexbar"

# The bundle only resolves when it sits beside the resolved executable; prove it before
# recording the path in the desktop's settings, through both the direct and linked names.
for entry in "$CLI_DIR/CodexBarCLI" "$PREFIX/bin/codexbar"; do
    CODEXBAR_RESOURCE_SMOKE=1 "$entry" | grep -Fxq CODEXBAR_RESOURCE_SMOKE_OK || {
        printf 'Resource bundle did not load through %s\n' "$entry" >&2
        exit 1
    }
done

printf '==> Building the Qt desktop\n'
mkdir -p "$BUILD_DIR"
(
    cd "$BUILD_DIR"
    PATH="$(system_path)" "$qmake" "$ROOT_DIR/Integrations/Linux/codexbar-linux.pro"
    PATH="$(system_path)" make -j"$(nproc)"
)

printf '==> Installing the desktop and launcher entry\n'
python3 "$ROOT_DIR/Integrations/Linux/install.py" \
    --binary "$BUILD_DIR/codexbar-linux" --cli "$PREFIX/bin/codexbar" "$@"

case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) printf 'Note: %s is not on PATH; add it to run codexbar from a shell.\n' "$PREFIX/bin" ;;
esac
