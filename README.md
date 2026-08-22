# Zed for Termux

Cross-compile Zed editor as a native Termux `.deb` package for aarch64.

## Problem

Zed cannot be built natively on Termux because `cranelift-codegen` (a wasmtime dependency) causes `rustc` to crash with SIGSEGV. This is a known issue ([termux-packages#21406](https://github.com/termux/termux-packages/issues/21406)).

## Solution

Cross-compile from Ubuntu using `aarch64-unknown-linux-musl` (static linking, no glibc dependency). The resulting binary runs natively on Termux.

## Quick Start (GitHub Actions)

1. Fork this repo
2. Go to Actions → "Build Zed for Termux" → Run workflow
3. Download the `.deb` artifact
4. Install on Termux:
   ```bash
   dpkg -i zed-termux_*.deb
   apt-get -f install
   ```

## Local Build (on Termux)

```bash
git clone <this-repo>
cd zed-termux-deb
bash scripts/build-local.sh
```

**Note:** Local builds take 2-4 hours and need 4GB+ free space.

## What Gets Patched

| Patch | Purpose |
|-------|---------|
| wasmtime cranelift → pulley | Avoid SIGSEGV in cranelift-codegen |
| rust-embed forced | Embed assets in binary statically |
| Home directory | Points to Termux home |
| Auto-update disabled | No update polling in Termux |

## Dependencies

The .deb declares these Termux dependencies:
- `libwayland`, `libxkbcommon` - Display server
- `fontconfig`, `freetype` - Font rendering
- `vulkan-loader` - GPU rendering
- `libgit2` - Git integration
- `openssl`, `libcurl` - Network
- `sqlite` - Local database
- `libandroid-glob` - Glob expansion

## Limitations

- GPU rendering may not work on all devices (Vulkan driver dependent)
- Some extensions requiring glibc won't work
- Collaborative editing (LiveKit) is disabled
- Audio features are stubbed

## Building the .deb Manually

```bash
# From a Linux machine with aarch64 cross-compiler:
cargo build --release --target aarch64-unknown-linux-musl -p zed
bash scripts/create-deb.sh aarch64-unknown-linux-musl
```

## File Structure

```
zed-termux-deb/
├── .github/workflows/build.yml   # CI pipeline
├── scripts/
│   ├── apply-patches.sh          # Patch Zed for Termux
│   ├── create-deb.sh             # Package as .deb
│   └── build-local.sh            # On-device build script
├── patches/                      # Additional patch files
└── README.md
```
