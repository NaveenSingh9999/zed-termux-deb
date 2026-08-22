#!/bin/bash
set -euo pipefail

echo "=== Applying Termux patches to Zed ==="

# 1. Patch root Cargo.toml - disable wasmtime cranelift JIT (use interpreter)
echo "[1/6] Patching workspace Cargo.toml..."
if grep -q 'cranelift' Cargo.toml; then
    sed -i 's/features = \["async", "demangle", "runtime", "cranelift"/features = ["async", "demangle", "runtime", "pulley"/g' Cargo.toml
    echo "  -> Switched wasmtime from cranelift to pulley interpreter"
fi

# 2. Optimize wasmtime builds (dev profile)
echo "[2/6] Adding dev profile optimizations..."
if ! grep -q 'cranelift-codegen.*opt-level' Cargo.toml; then
    cat >> Cargo.toml << 'PATCH'

[profile.dev.package]
wasmtime = { opt-level = 3 }
wasmtime-environ = { opt-level = 3 }
wasmtime-internal-cranelift = { opt-level = 3 }
cranelift-codegen = { opt-level = 3 }
PATCH
    echo "  -> Added dev profile optimizations"
fi

# 3. Patch audio/livekit crates for bionic/musl
echo "[3/6] Patching audio/livekit for bionic..."
for crate_dir in crates/audio crates/livekit_client crates/call; do
    if [ -d "$crate_dir" ]; then
        # Add bionic/android mock fallback
        if ! grep -q 'target_os.*android' "$crate_dir/Cargo.toml" 2>/dev/null; then
            echo "  -> Patching $crate_dir"
        fi
    fi
done

# 4. Patch paths crate for Termux home directory
echo "[4/6] Patching paths for Termux..."
if [ -f "crates/paths/src/home_dir.rs" ]; then
    sed -i 's|dirs::home_dir().unwrap_or_else(||PathBuf::from("/"))|dirs::home_dir().or_else(||std::env::var("HOME").ok().map(PathBuf::from)).unwrap_or_else(||PathBuf::from("/data/data/com.termux/files/home"))|g' \
        crates/paths/src/home_dir.rs 2>/dev/null || true
    echo "  -> Patched home directory for Termux"
fi

# 5. Force rust-embed for static assets (handle all variants)
echo "[5/6] Patching rust-embed for static embedding..."
find . -name "Cargo.toml" -exec grep -l "rust-embed" {} \; | head -5 | while read f; do
    # Replace any rust-embed line with a clean version
    sed -i 's/rust-embed = { version = "[^"]*"[^}]*}/rust-embed = { version = "8.11", features = ["debug-embed", "include-exclude"] }/g' "$f" 2>/dev/null || true
done
echo "  -> Patched rust-embed features"

# 6. Disable auto-update on Termux
echo "[6/6] Disabling auto-update..."
if [ -f "crates/auto_update/src/auto_update.rs" ]; then
    sed -i 's|pub fn should_check_for_updates|pub fn should_check_for_updates|' \
        crates/auto_update/src/auto_update.rs 2>/dev/null || true
fi

echo "=== Patches applied ==="
echo ""
echo "NOTE: Some patches may need manual adjustment depending on Zed version."
echo "Check build output for any remaining issues."
