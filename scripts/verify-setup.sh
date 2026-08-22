#!/bin/bash
set -euo pipefail

echo "=== Zed Termux Build - Verification ==="
echo ""

ERRORS=0

# Check Rust
if command -v rustc &>/dev/null; then
    echo "[OK] Rust: $(rustc --version)"
    if rustup target list --installed 2>/dev/null | grep -q musl; then
        echo "[OK] musl target installed"
    else
        echo "[WARN] musl target not installed"
        echo "  Run: rustup target add aarch64-unknown-linux-musl"
    fi
else
    echo "[ERROR] Rust not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check cross-compiler
if command -v aarch64-linux-gnu-gcc &>/dev/null; then
    echo "[OK] aarch64 cross-compiler: $(aarch64-linux-gnu-gcc --version | head -1)"
else
    echo "[WARN] aarch64-linux-gnu-gcc not found (needed for cross-compile)"
fi

# Check cargo-deb
if command -v cargo-deb &>/dev/null; then
    echo "[OK] cargo-deb installed"
else
    echo "[WARN] cargo-deb not installed"
    echo "  Run: cargo install cargo-deb"
fi

# Check disk space
DISK_FREE=$(df -BG . | tail -1 | awk '{print $4}' | tr -d 'G')
if [ "$DISK_FREE" -ge 20 ]; then
    echo "[OK] Disk space: ${DISK_FREE}GB free"
else
    echo "[WARN] Low disk space: ${DISK_FREE}GB (need 20GB+)"
fi

# Check if Zed is cloned
if [ -d "zed-src" ]; then
    echo "[OK] Zed source found"
else
    echo "[INFO] Zed not cloned yet"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "Setup looks good. Run 'bash scripts/build-local.sh' to build."
else
    echo "Fix the errors above before building."
fi
