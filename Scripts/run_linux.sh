#!/usr/bin/env bash

# Linux dev loop: build the Qt desktop from source, stop any running instance, relaunch the
# freshly built binary, and confirm it stays up. Arguments are passed to the launched app.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${CODEXBAR_LINUX_BUILD_DIR:-$ROOT_DIR/.local/linux-build}"
BINARY="$BUILD_DIR/codexbar-linux"
LOG="$BUILD_DIR/codexbar-linux.log"

# A Homebrew-on-Linux toolchain resolves its own linker and libgomp, which target a newer glibc
# than Enterprise Linux 9 provides, so the desktop fails to link. Build with the system one.
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

qmake="$(find_qmake)"

printf '==> Building the Qt desktop\n'
mkdir -p "$BUILD_DIR"
(
    cd "$BUILD_DIR"
    PATH="$(system_path)" "$qmake" "$ROOT_DIR/Integrations/Linux/codexbar-linux.pro"
    PATH="$(system_path)" make -j"$(nproc)"
)

# Stop whatever is running first, including an installed copy, so the socket is free and the
# window that comes up is the build we just made rather than the previous one.
printf '==> Stopping any running instance\n'
for candidate in "$BINARY" "$HOME/.local/bin/codexbar-linux"; do
    [[ -x "$candidate" ]] && "$candidate" --quit >/dev/null 2>&1 || true
done
pkill -x codexbar-linux >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x codexbar-linux >/dev/null 2>&1 || break
    sleep 0.2
done

settings="${XDG_CONFIG_HOME:-$HOME/.config}/codexbar/linux.json"
if [[ ! -f "$settings" ]]; then
    printf 'Note: no %s yet. Run "make install" once to record a CLI path.\n' "$settings"
fi

printf '==> Launching %s\n' "$BINARY"
: >"$LOG"
"$BINARY" "${@:---usage}" >>"$LOG" 2>&1 &
launched=$!

# A desktop that exits immediately (no CLI, no display, a busy socket) is the common failure;
# report its output instead of leaving a silent success behind.
sleep 2
if ! kill -0 "$launched" 2>/dev/null; then
    printf 'CodexBar exited right after launch:\n' >&2
    cat "$LOG" >&2
    exit 1
fi
printf '==> Running (pid %s); log at %s\n' "$launched" "$LOG"
