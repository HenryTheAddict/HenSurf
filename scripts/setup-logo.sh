#!/bin/bash

# HenSurf Logo Setup Script
# This script integrates the HenSurf logo and icons into the Chromium build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CHROMIUM_SRC="$PROJECT_ROOT/chromium/src"
BRANDING_DIR="$PROJECT_ROOT/branding"
ICONS_DIR="$BRANDING_DIR/icons"

echo "Setting up HenSurf logo and icons..."

# Check if Chromium source exists
if [ ! -d "$CHROMIUM_SRC" ]; then
    echo "Error: Chromium source not found at $CHROMIUM_SRC"
    echo "Please run fetch-chromium.sh first"
    exit 1
fi

# Check if icons exist
if [ ! -d "$ICONS_DIR" ]; then
    echo "Error: Icons directory not found at $ICONS_DIR"
    echo "Please ensure the logo has been processed into icons"
    exit 1
fi

# Create Chrome app icon directories
echo "Creating Chrome app icon directories..."
mkdir -p "$CHROMIUM_SRC/chrome/app/theme/chromium"
mkdir -p "$CHROMIUM_SRC/chrome/app/theme/default_100_percent/chromium"
mkdir -p "$CHROMIUM_SRC/chrome/app/theme/default_200_percent/chromium"

# Copy icons to Chrome app theme directories
echo "Copying icons to Chrome app theme directories..."
cp "$ICONS_DIR/icon_16.png" "$CHROMIUM_SRC/chrome/app/theme/chromium/product_logo_16.png"
cp "$ICONS_DIR/icon_32.png" "$CHROMIUM_SRC/chrome/app/theme/chromium/product_logo_32.png"
cp "$ICONS_DIR/icon_48.png" "$CHROMIUM_SRC/chrome/app/theme/default_100_percent/chromium/product_logo_48.png"
cp "$ICONS_DIR/icon_64.png" "$CHROMIUM_SRC/chrome/app/theme/chromium/product_logo_64.png"
cp "$ICONS_DIR/icon_128.png" "$CHROMIUM_SRC/chrome/app/theme/chromium/product_logo_128.png"
cp "$ICONS_DIR/icon_256.png" "$CHROMIUM_SRC/chrome/app/theme/chromium/product_logo_256.png"

# Copy high-res icons for Retina displays
cp "$ICONS_DIR/icon_32.png" "$CHROMIUM_SRC/chrome/app/theme/default_200_percent/chromium/product_logo_16.png"
cp "$ICONS_DIR/icon_64.png" "$CHROMIUM_SRC/chrome/app/theme/default_200_percent/chromium/product_logo_32.png"
cp "$ICONS_DIR/icon_96.png" "$CHROMIUM_SRC/chrome/app/theme/default_200_percent/chromium/product_logo_48.png" 2>/dev/null || cp "$ICONS_DIR/icon_128.png" "$CHROMIUM_SRC/chrome/app/theme/default_200_percent/chromium/product_logo_48.png"

# Copy icons for Windows ICO format (if on Windows or cross-compiling)
if command -v convert >/dev/null 2>&1; then
    echo "Creating Windows ICO file..."
    convert "$ICONS_DIR/icon_16.png" "$ICONS_DIR/icon_32.png" "$ICONS_DIR/icon_48.png" "$ICONS_DIR/icon_64.png" "$ICONS_DIR/icon_128.png" "$ICONS_DIR/icon_256.png" "$CHROMIUM_SRC/chrome/app/theme/chromium/chrome.ico"
else
    echo "ImageMagick not found, skipping ICO creation"
fi

# Copy favicon
echo "Setting up favicon..."
cp "$ICONS_DIR/icon_32.png" "$CHROMIUM_SRC/chrome/app/theme/chromium/favicon.png"

# Update Chrome branding files
echo "Updating Chrome branding files..."

# Create or update chrome_exe.ver for Windows builds
cat > "$CHROMIUM_SRC/chrome/app/chrome_exe.ver" << EOF
#include "chrome/app/chrome_version.rc.version"

#define PRODUCT_FULLNAME_STRING "HenSurf Browser"
#define PRODUCT_SHORTNAME_STRING "HenSurf"
#define COMPANY_FULLNAME_STRING "HenSurf"
#define COMPANY_SHORTNAME_STRING "HenSurf"
#define COPYRIGHT_STRING "Copyright 2025 HenSurf. All rights reserved."
EOF

# Update app icon references in BUILD.gn files
# echo "Updating BUILD.gn icon references..." # Section commented out
# The following section related to modifying chrome/app/BUILD.gn for icon paths
# has been commented out because:
# 1. The original sed command `sed -i.bak 's/chromium\/product_logo/chromium\/product_logo/g'` was a no-operation,
#    replacing a string with itself. It provided no functional change.
# 2. Chromium typically handles icons by looking for specific filenames (e.g., product_logo_*.png, app.icns, chrome.ico)
#    within designated theme directories (e.g., chrome/app/theme/chromium/, default_100_percent, etc.).
#    The rest of this script correctly places the HenSurf icons into these directories with the expected names.
# 3. If specific BUILD.gn modifications were truly necessary (e.g., to change target names or file paths
#    if non-standard names/locations were used), a more targeted and accurate sed command or gn edit operation
#    would be required.
# As such, directly modifying BUILD.gn with the provided sed command is unnecessary and potentially misleading.

# if [ -f "$CHROMIUM_SRC/chrome/app/BUILD.gn" ]; then
    # Backup original BUILD.gn
    # cp "$CHROMIUM_SRC/chrome/app/BUILD.gn" "$CHROMIUM_SRC/chrome/app/BUILD.gn.backup-hensurf-logo-setup" # Changed backup name for clarity
    
    # Update icon references (this is a simplified approach)
    # sed -i.bak 's/chromium\/product_logo/chromium\/product_logo/g' "$CHROMIUM_SRC/chrome/app/BUILD.gn"
    # if [ -f "$CHROMIUM_SRC/chrome/app/BUILD.gn.bak" ]; then # Check if .bak was created by sed
    #    rm "$CHROMIUM_SRC/chrome/app/BUILD.gn.bak"
    # fi
# fi

# Create macOS app icon (ICNS) if on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Creating macOS app icon (ICNS)..."
    
    # Create iconset directory
    ICONSET_DIR="$CHROMIUM_SRC/chrome/app/theme/chromium/app.iconset"
    mkdir -p "$ICONSET_DIR"
    
    # Copy icons with proper naming for iconset
    cp "$ICONS_DIR/icon_16.png" "$ICONSET_DIR/icon_16x16.png"
    cp "$ICONS_DIR/icon_32.png" "$ICONSET_DIR/icon_16x16@2x.png"
    cp "$ICONS_DIR/icon_32.png" "$ICONSET_DIR/icon_32x32.png"
    cp "$ICONS_DIR/icon_64.png" "$ICONSET_DIR/icon_32x32@2x.png"
    cp "$ICONS_DIR/icon_128.png" "$ICONSET_DIR/icon_128x128.png"
    cp "$ICONS_DIR/icon_256.png" "$ICONSET_DIR/icon_128x128@2x.png"
    cp "$ICONS_DIR/icon_256.png" "$ICONSET_DIR/icon_256x256.png"
    cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR/icon_256x256@2x.png"
    cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR/icon_512x512.png"
    
    # Create ICNS file
    iconutil -c icns "$ICONSET_DIR" -o "$CHROMIUM_SRC/chrome/app/theme/chromium/app.icns"
    
    # Clean up iconset directory
    rm -rf "$ICONSET_DIR"
fi

echo "Logo and icon setup completed successfully!"
echo "Icons have been integrated into the Chromium build system."
echo "The HenSurf logo will be used as the browser icon when you build the project."