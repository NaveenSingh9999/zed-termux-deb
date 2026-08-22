#!/bin/bash
set -euo pipefail

TARGET="${1:-aarch64-unknown-linux-musl}"
VERSION=$(grep '^version' crates/zed/Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
ARCH="aarch64"
DEB_NAME="zed-termux_${VERSION}_${ARCH}.deb"
BUILD_DIR="../zed-termux-pkg"
PREFIX="/data/data/com.termux/files/usr"

echo "=== Creating Termux .deb package ==="
echo "Version: $VERSION"
echo "Target: $TARGET"
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/bin"
mkdir -p "$BUILD_DIR/lib"
mkdir -p "$BUILD_DIR/share/applications"
mkdir -p "$BUILD_DIR/share/icons/hicolor/256x256/apps"
mkdir -p "$BUILD_DIR/share/zed"

# Find and copy the built binary
BINARY_PATH="target/$TARGET/release/zed"
if [ ! -f "$BINARY_PATH" ]; then
    BINARY_PATH="target/$TARGET/debug/zed"
fi

if [ -f "$BINARY_PATH" ]; then
    cp "$BINARY_PATH" "$BUILD_DIR/bin/zed"
    chmod 755 "$BUILD_DIR/bin/zed"
    echo "Copied binary: $(file "$BUILD_DIR/bin/zed")"
else
    echo "ERROR: Binary not found at $BINARY_PATH"
    echo "Available binaries:"
    find target/ -name "zed" -type f 2>/dev/null
    exit 1
fi

# Copy zd-exec helper if built
ZD_EXEC="target/$TARGET/release/zd-exec"
if [ -f "$ZD_EXEC" ]; then
    cp "$ZD_EXEC" "$BUILD_DIR/bin/zd-exec"
    chmod 755 "$BUILD_DIR/bin/zd-exec"
fi

# Copy assets
if [ -d "assets" ]; then
    cp -r assets/* "$BUILD_DIR/share/zed/" 2>/dev/null || true
fi

# Copy themes
if [ -d "assets/themes" ]; then
    cp -r assets/themes "$BUILD_DIR/share/zed/" 2>/dev/null || true
fi

# Create .desktop file
cat > "$BUILD_DIR/share/applications/dev.zed.Zed.desktop" << 'DESKTOP'
[Desktop Entry]
Name=Zed
Comment=Zed is a fast, multiplayer code editor
Exec=zed %F
Icon=dev.zed.Zed
Type=Application
Categories=Development;TextEditor;
MimeType=text/plain;inode/directory;
DESKTOP

# Create icon placeholder (4x4 PNG)
echo "NOTE: Replace with actual Zed icon"

# Calculate installed size
INSTALLED_SIZE=$(du -sk "$BUILD_DIR" | cut -f1)

# Create control file
mkdir -p "$BUILD_DIR/DEBIAN"
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: zed-termux
Version: ${VERSION}
Architecture: ${ARCH}
Maintainer: Zed Termux Build <noreply@github.com>
Depends: libandroid-glob, libwayland, libxkbcommon, fontconfig, freetype,
 vulkan-loader, libgit2, openssl, libcurl, sqlite,
termux-tools (>= 0.38)
Recommends: x11-repo
Section: editors
Priority: optional
Homepage: https://zed.dev
Description: Zed - A high-performance, multiplayer code editor
 Zed is a fast, multiplayer code editor from the creators of Atom and
 Tree-sitter. It's built in Rust for performance and uses GPU rendering.
 .
 This package is cross-compiled for Termux aarch64 with musl static linking.
 .
 Features:
  - Lightning-fast editing
  - Built-in terminal
  - Git integration
  - AI assistance
  - Collaborative editing
Installed-Size: ${INSTALLED_SIZE}
EOF

# Create md5sums
(cd "$BUILD_DIR" && find . -type f ! -path "./DEBIAN/*" -exec md5sum {} \; | sed 's|^\./||' > DEBIAN/md5sums)

# Build the .deb
echo ""
echo "Building $DEB_NAME..."
dpkg-deb --build --root-owner-group "$BUILD_DIR" "$DEB_NAME"

echo ""
echo "=== Package created ==="
ls -lh "$DEB_NAME"
echo ""
echo "To install on Termux:"
echo "  dpkg -i $DEB_NAME"
echo "  apt-get -f install"
echo ""
echo "To install via file transfer:"
echo "  adb push $DEB_NAME /sdcard/"
echo "  # Then in Termux:"
echo "  cp /sdcard/$DEB_NAME ~/"
echo "  dpkg -i ~/$DEB_NAME"
