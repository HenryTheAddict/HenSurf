#!/bin/bash

# HenSurf Logo Setup Script
# This script integrates the HenSurf logo and icons into the Chromium build

set -e

# Source utility functions
SCRIPT_DIR_SETUP_LOGO=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR_SETUP_LOGO/utils.sh"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR_SETUP_LOGO")"
CHROMIUM_SRC="$PROJECT_ROOT/chromium/src"
BRANDING_DIR="$PROJECT_ROOT/branding"
ICONS_DIR="$BRANDING_DIR/icons"

log_info "🎨 Setting up HenSurf logo and icons..."

# Check if Chromium source exists
if [ ! -d "$CHROMIUM_SRC" ]; then
    log_error "❌ Chromium source not found at $CHROMIUM_SRC"
    log_error "   Please run fetch-chromium.sh first."
    exit 1
fi
log_success "✅ Chromium source directory found: $CHROMIUM_SRC"

# Check if icons exist
if [ ! -d "$ICONS_DIR" ]; then
    log_error "❌ Icons directory not found at $ICONS_DIR"
    log_error "   Please ensure the logo has been processed into icons (e.g., by running a branding generation script)."
    exit 1
fi
log_success "✅ Icons directory found: $ICONS_DIR"

# Define target directories
THEME_CHROMIUM_DIR="$CHROMIUM_SRC/chrome/app/theme/chromium"
THEME_100_PERCENT_DIR="$CHROMIUM_SRC/chrome/app/theme/default_100_percent/chromium"
THEME_200_PERCENT_DIR="$CHROMIUM_SRC/chrome/app/theme/default_200_percent/chromium"

# Create Chrome app icon directories
log_info "Creating Chrome app icon directories..."
log_info "Creating directory: $THEME_CHROMIUM_DIR"
mkdir -p "$THEME_CHROMIUM_DIR"
log_info "Creating directory: $THEME_100_PERCENT_DIR"
mkdir -p "$THEME_100_PERCENT_DIR"
log_info "Creating directory: $THEME_200_PERCENT_DIR"
mkdir -p "$THEME_200_PERCENT_DIR"
log_success "✅ Chrome app icon directories created/ensured."

# Copy icons to Chrome app theme directories
log_info "Copying standard resolution icons to Chrome app theme directories..."
log_info "Copying $ICONS_DIR/icon_16.png to $THEME_CHROMIUM_DIR/product_logo_16.png"
cp "$ICONS_DIR/icon_16.png" "$THEME_CHROMIUM_DIR/product_logo_16.png"
log_info "Copying $ICONS_DIR/icon_32.png to $THEME_CHROMIUM_DIR/product_logo_32.png"
cp "$ICONS_DIR/icon_32.png" "$THEME_CHROMIUM_DIR/product_logo_32.png"
log_info "Copying $ICONS_DIR/icon_48.png to $THEME_100_PERCENT_DIR/product_logo_48.png"
cp "$ICONS_DIR/icon_48.png" "$THEME_100_PERCENT_DIR/product_logo_48.png"
log_info "Copying $ICONS_DIR/icon_64.png to $THEME_CHROMIUM_DIR/product_logo_64.png"
cp "$ICONS_DIR/icon_64.png" "$THEME_CHROMIUM_DIR/product_logo_64.png"
log_info "Copying $ICONS_DIR/icon_128.png to $THEME_CHROMIUM_DIR/product_logo_128.png"
cp "$ICONS_DIR/icon_128.png" "$THEME_CHROMIUM_DIR/product_logo_128.png"
log_info "Copying $ICONS_DIR/icon_256.png to $THEME_CHROMIUM_DIR/product_logo_256.png"
cp "$ICONS_DIR/icon_256.png" "$THEME_CHROMIUM_DIR/product_logo_256.png"
log_success "✅ Standard resolution icons copied."

# Copy high-res icons for Retina displays (200% scaling)
log_info "Copying high-resolution (200%) icons for Retina displays..."
log_info "Copying $ICONS_DIR/icon_32.png to $THEME_200_PERCENT_DIR/product_logo_16.png (16px@200%)"
cp "$ICONS_DIR/icon_32.png" "$THEME_200_PERCENT_DIR/product_logo_16.png"
log_info "Copying $ICONS_DIR/icon_64.png to $THEME_200_PERCENT_DIR/product_logo_32.png (32px@200%)"
cp "$ICONS_DIR/icon_64.png" "$THEME_200_PERCENT_DIR/product_logo_32.png"

# Specific handling for product_logo_48.png at 200% (expects 96px actual)
TARGET_48_200="$THEME_200_PERCENT_DIR/product_logo_48.png"
if [ -f "$ICONS_DIR/icon_96.png" ]; then
    log_info "Copying $ICONS_DIR/icon_96.png to $TARGET_48_200 (48px@200%)"
    cp "$ICONS_DIR/icon_96.png" "$TARGET_48_200"
elif [ -f "$ICONS_DIR/icon_128.png" ]; then
    log_warn "⚠️ $ICONS_DIR/icon_96.png not found for 48px@200%. Using $ICONS_DIR/icon_128.png as fallback."
    log_info "Copying $ICONS_DIR/icon_128.png to $TARGET_48_200"
    cp "$ICONS_DIR/icon_128.png" "$TARGET_48_200"
else
    log_error "❌ Missing suitable icon for 48px@200% (expected $ICONS_DIR/icon_96.png, fallback $ICONS_DIR/icon_128.png not found either)."
    # Decide if this is a fatal error or can be skipped. For now, just log error.
fi
log_success "✅ High-resolution icons copied."

# Copy icons for Windows ICO format
if command_exists "convert"; then
    log_info "ImageMagick 'convert' command found. Creating Windows ICO file: $THEME_CHROMIUM_DIR/chrome.ico"
    convert "$ICONS_DIR/icon_16.png" "$ICONS_DIR/icon_32.png" "$ICONS_DIR/icon_48.png" "$ICONS_DIR/icon_64.png" "$ICONS_DIR/icon_128.png" "$ICONS_DIR/icon_256.png" "$THEME_CHROMIUM_DIR/chrome.ico"
    log_success "✅ Windows ICO file created: $THEME_CHROMIUM_DIR/chrome.ico"
else
    log_warn "⚠️ ImageMagick 'convert' command not found, skipping Windows ICO creation. Windows builds may lack a proper application icon."
fi

# Copy favicon
log_info "Setting up favicon..."
log_info "Copying $ICONS_DIR/icon_32.png to $THEME_CHROMIUM_DIR/favicon.png"
cp "$ICONS_DIR/icon_32.png" "$THEME_CHROMIUM_DIR/favicon.png"
log_success "✅ Favicon setup complete."

# Update Chrome branding files
log_info "Updating Chrome branding files..."
CHROME_EXE_VER_PATH="$CHROMIUM_SRC/chrome/app/chrome_exe.ver"
log_info "Creating or updating $CHROME_EXE_VER_PATH for Windows builds..."
cat > "$CHROME_EXE_VER_PATH" << EOF
#include "chrome/app/chrome_version.rc.version"

#define PRODUCT_FULLNAME_STRING "HenSurf Browser"
#define PRODUCT_SHORTNAME_STRING "HenSurf"
#define COMPANY_FULLNAME_STRING "HenSurf"
#define COMPANY_SHORTNAME_STRING "HenSurf"
#define COPYRIGHT_STRING "Copyright 2025 HenSurf. All rights reserved."
EOF
log_success "✅ $CHROME_EXE_VER_PATH updated."

# Information about BUILD.gn modifications
log_info "Regarding chrome/app/BUILD.gn icon path modifications:"
log_info "  Modifying BUILD.gn for icon paths is generally not needed."
log_info "  Chromium typically handles icons by looking for specific filenames (e.g., product_logo_*.png, app.icns, chrome.ico)"
log_info "  within designated theme directories, which this script adheres to."
log_info "  The original sed command in earlier versions of this script was a no-operation and has been removed."
log_info "  If custom icon names or paths were used, BUILD.gn would need careful, targeted updates."

# Create macOS app icon (ICNS) if on macOS
OS_TYPE=$(get_os_type)
if [[ "$OS_TYPE" == "macos" ]]; then
    log_info "🍏 Detected macOS. Creating macOS app icon (app.icns)..."
    
    ICONSET_DIR="$THEME_CHROMIUM_DIR/app.iconset"
    log_info "Creating iconset directory: $ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    
    log_info "Copying icons with proper naming for iconset..."
    cp "$ICONS_DIR/icon_16.png" "$ICONSET_DIR/icon_16x16.png"
    cp "$ICONS_DIR/icon_32.png" "$ICONSET_DIR/icon_16x16@2x.png"
    cp "$ICONS_DIR/icon_32.png" "$ICONSET_DIR/icon_32x32.png"
    cp "$ICONS_DIR/icon_64.png" "$ICONSET_DIR/icon_32x32@2x.png"
    cp "$ICONS_DIR/icon_128.png" "$ICONSET_DIR/icon_128x128.png"
    cp "$ICONS_DIR/icon_256.png" "$ICONSET_DIR/icon_128x128@2x.png"
    cp "$ICONS_DIR/icon_256.png" "$ICONSET_DIR/icon_256x256.png"
    cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR/icon_256x256@2x.png"
    cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR/icon_512x512.png"
    # Optional: A 1024px image for icon_512x512@2x.png if available
    if [ -f "$ICONS_DIR/icon_1024.png" ]; then
        log_info "Copying $ICONS_DIR/icon_1024.png to $ICONSET_DIR/icon_512x512@2x.png"
        cp "$ICONS_DIR/icon_1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
    else
        log_warn "⚠️  $ICONS_DIR/icon_1024.png not found, using $ICONS_DIR/icon_512.png for 512x512@2x. This might result in a lower resolution icon for the largest size on Retina displays."
        cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR/icon_512x512@2x.png"
    fi
    
    if command_exists "iconutil"; then
        log_info "Generating ICNS file using iconutil: $THEME_CHROMIUM_DIR/app.icns"
        iconutil -c icns "$ICONSET_DIR" -o "$THEME_CHROMIUM_DIR/app.icns"
        log_success "✅ macOS app.icns created successfully."
    else
        log_error "❌ 'iconutil' command not found on macOS. Cannot create .icns file."
        log_error "   Please ensure Xcode Command Line Tools are installed."
    fi
    
    log_info "Cleaning up iconset directory: $ICONSET_DIR"
    rm -rf "$ICONSET_DIR"
    log_success "✅ Iconset directory removed."
else
    log_info "OS is not macOS ($OS_TYPE), skipping ICNS creation."
fi

log_success "🎉 Logo and icon setup completed successfully!"
log_info "   Icons have been integrated into the Chromium build system."
log_info "   The HenSurf logo will be used as the browser icon when you build the project."