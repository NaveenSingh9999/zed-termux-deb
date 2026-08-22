#!/bin/bash
set -euo pipefail

echo "=== Zed for Termux - Local Build Script ==="
echo ""
echo "This script builds Zed natively on Termux for aarch64."
echo "WARNING: This may take 2-4 hours and requires 4GB+ free RAM/disk."
echo ""

# Check if running on Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo "ERROR: This script must be run on Termux."
    echo "For CI builds, use the GitHub Actions workflow instead."
    exit 1
fi

# Install dependencies
echo "[1/5] Installing dependencies..."
pkg update -y
pkg install -y \
    rust git cmake ninja-build \
    libwayland libxkbcommon fontconfig freetype \
    vulkan-headers vulkan-loader \
    libgit2 openssl libcurl \
    sqlite libandroid-glob \
    build-essential python3

# Install rustup (if not present)
if ! command -v rustup &>/dev/null; then
    echo "[2/5] Installing rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
else
    echo "[2/5] rustup already installed"
    source ~/.cargo/env
fi

# Add musl target
echo "[3/5] Adding musl target..."
rustup target add aarch64-unknown-linux-musl || true

# Clone and patch Zed
echo "[4/5] Cloning Zed..."
if [ ! -d "zed-src" ]; then
    git clone --recursive --depth 1 https://github.com/zed-industries/zed.git zed-src
fi

cd zed-src
bash ../scripts/apply-patches.sh

# Configure for musl
mkdir -p .cargo
cat > .cargo/config.toml << 'EOF'
[build]
rustflags = ["-C", "symbol-mangling-version=v0", "--cfg", "tokio_unstable"]

[target.aarch64-unknown-linux-musl]
rustflags = ["-C", "target-feature=+crt-static", "-C", "link-arg=-static"]
EOF

# Build
echo "[5/5] Building Zed (this will take a while)..."
cargo build \
    --release \
    --target aarch64-unknown-linux-musl \
    -p zed \
    2>&1 | tee ../build.log

# Create .deb
bash ../scripts/create-deb.sh aarch64-unknown-linux-musl

echo ""
echo "=== Build complete ==="
echo "Check ../ for the .deb file"
