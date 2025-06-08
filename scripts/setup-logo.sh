#!/bin/bash

# HenSurf Logo Setup Script
# This script integrates the HenSurf logo and icons into the Chromium build

set -e

# Source utility functions
SCRIPT_DIR_SETUP_LOGO=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR_SETUP_LOGO/utils.sh" # Provides log_* and safe_cd

# Define project structure variables
# PROJECT_ROOT is the top-level directory of the HenSurf Browser project.
PROJECT_ROOT=$(cd "$SCRIPT_DIR_SETUP_LOGO/.." &>/dev/null && pwd)
# CHROMIUM_SRC is the path to the Chromium source directory, now at src/chromium.
# This variable is kept for context but this script will not write into it directly.
CHROMIUM_SRC="$PROJECT_ROOT/src/chromium"
# BRANDING_DIR contains the HenSurf source branding assets (icons, etc.).
BRANDING_DIR="$PROJECT_ROOT/src/hensurf/branding"
# ICONS_DIR is where source PNG icons are stored.
ICONS_DIR="$BRANDING_DIR/icons"

# HENSURF_ASSETS_DEST_DIR is the new root for all staged output files.
HENSURF_ASSETS_DEST_DIR="$PROJECT_ROOT/src/hensurf/branding/distributable_assets/chromium"

# Content for the HenSurf BRANDING file
# Matches content from integrate-logo.patch
HENSURF_BRANDING_FILE_CONTENT="COMPANY_FULLNAME=HenSurf
COMPANY_SHORTNAME=HenSurf
PRODUCT_FULLNAME=HenSurf Browser
PRODUCT_SHORTNAME=HenSurf
PRODUCT_INSTALLER_FULLNAME=HenSurf Browser Installer
COPYRIGHT=Copyright 2025 HenSurf. All rights reserved.
OFFICIAL_BUILD=1
MAC_BUNDLE_ID=xyz.h3nry.hensurf"

log_info "🎨 Staging HenSurf logo, icons, and branding files into $HENSURF_ASSETS_DEST_DIR"

# --- Pre-flight Checks ---
log_info "🔎 Performing pre-flight checks..."
# Chromium source directory check can remain for context, though not directly used for output.
if [ ! -d "$CHROMIUM_SRC" ]; then
    log_warn "⚠️ Chromium source directory not found at '$CHROMIUM_SRC'. This script primarily stages assets, but context might be missing."
    # exit 1 # Not strictly fatal for this script's new purpose
fi
# log_success "✅ Chromium source directory found: $CHROMIUM_SRC" # Less relevant now

if [ ! -d "$ICONS_DIR" ]; then
    log_error "❌ Source icons directory not found at '$ICONS_DIR'."
    log_error "   This directory should contain pre-processed PNG icons (icon_16.png, icon_32.png, etc.)."
    log_error "   Ensure branding assets are correctly placed in '$BRANDING_DIR/icons/'."
    exit 1
fi
log_success "✅ Source icons directory found: $ICONS_DIR"

# Ensure the main destination directory exists
mkdir -p "$HENSURF_ASSETS_DEST_DIR"
log_success "✅ Ensured destination directory exists: $HENSURF_ASSETS_DEST_DIR"

# --- Main Setup Logic ---

# No longer cd into CHROMIUM_SRC. All paths are now absolute or relative to PROJECT_ROOT or HENSURF_ASSETS_DEST_DIR.
# log_info "Working inside Chromium source directory: $(pwd)" # Removed

# Define target theme directories within HENSURF_ASSETS_DEST_DIR
DEST_APP_DIR="$HENSURF_ASSETS_DEST_DIR/chrome/app"
DEST_THEME_MAIN_DIR="$DEST_APP_DIR/theme"
DEST_THEME_CHROMIUM_DIR="$DEST_THEME_MAIN_DIR/chromium"
DEST_THEME_100_PERCENT_DIR="$DEST_THEME_MAIN_DIR/default_100_percent/chromium"
DEST_THEME_200_PERCENT_DIR="$DEST_THEME_MAIN_DIR/default_200_percent/chromium"

# Create necessary destination theme directories
log_info "🔧 Ensuring destination theme directories exist..."
mkdir -p "$DEST_THEME_CHROMIUM_DIR"
mkdir -p "$DEST_THEME_100_PERCENT_DIR"
mkdir -p "$DEST_THEME_200_PERCENT_DIR"
# DEST_APP_DIR for chrome_exe.ver
mkdir -p "$DEST_APP_DIR"
log_success "✅ Destination theme directories ensured."

# Create HenSurf BRANDING file in the destination
log_info "📝 Creating HenSurf BRANDING file..."
# This BRANDING file is specific to what Chromium expects in its theme structure.
# The path used here mimics where Chromium would look for it if 'hensurf' was a theme inside chrome/app/theme.
# This might need adjustment if the build system is to pick it up from a different relative path.
# For now, placing it analogous to chrome/app/theme/chromium/BRANDING.
# A more specific HenSurf theme might be src/hensurf/branding/theme/hensurf/BRANDING.
# This part is creating the one that would have been at chrome/app/theme/chromium/BRANDING effectively.
DEST_BRANDING_FILE_PATH="$DEST_THEME_CHROMIUM_DIR/BRANDING"
echo -e "$HENSURF_BRANDING_FILE_CONTENT" > "$DEST_BRANDING_FILE_PATH"
log_success "✅ HenSurf BRANDING file created at '$DEST_BRANDING_FILE_PATH'."

# Copy standard resolution PNG icons to destination
log_info "🖼️ Copying standard resolution PNG icons to $HENSURF_ASSETS_DEST_DIR..."
cp "$ICONS_DIR/icon_16.png" "$DEST_THEME_CHROMIUM_DIR/product_logo_16.png"
cp "$ICONS_DIR/icon_32.png" "$DEST_THEME_CHROMIUM_DIR/product_logo_32.png"
cp "$ICONS_DIR/icon_48.png" "$DEST_THEME_100_PERCENT_DIR/product_logo_48.png"
cp "$ICONS_DIR/icon_64.png" "$DEST_THEME_CHROMIUM_DIR/product_logo_64.png"
cp "$ICONS_DIR/icon_128.png" "$DEST_THEME_CHROMIUM_DIR/product_logo_128.png"
cp "$ICONS_DIR/icon_256.png" "$DEST_THEME_CHROMIUM_DIR/product_logo_256.png"
log_success "✅ Standard resolution icons copied."

# Copy high-resolution (200%) PNG icons to destination
log_info "🖼️ Copying high-resolution (200%) PNG icons to $HENSURF_ASSETS_DEST_DIR..."
cp "$ICONS_DIR/icon_32.png" "$DEST_THEME_200_PERCENT_DIR/product_logo_16.png"  # 16px@2x = 32px
cp "$ICONS_DIR/icon_64.png" "$DEST_THEME_200_PERCENT_DIR/product_logo_32.png"  # 32px@2x = 64px

TARGET_48_200_PATH="$DEST_THEME_200_PERCENT_DIR/product_logo_48.png"
if [ -f "$ICONS_DIR/icon_96.png" ]; then
    cp "$ICONS_DIR/icon_96.png" "$TARGET_48_200_PATH"
    log_info "   Copied icon_96.png for 48px@200%."
elif [ -f "$ICONS_DIR/icon_128.png" ]; then
    cp "$ICONS_DIR/icon_128.png" "$TARGET_48_200_PATH"
    log_warn "   ⚠️ Icon 'icon_96.png' not found. Used 'icon_128.png' as fallback for 48px@200%."
else
    log_error "❌ Missing suitable icon for 48px@200% (expected 'icon_96.png' or 'icon_128.png')."
fi
log_success "✅ High-resolution icons copied."

# Create Windows ICO file in destination
log_info "🖼️ Preparing Windows ICO file (chromium.ico) in $HENSURF_ASSETS_DEST_DIR..."
DEST_WIN_ICON_DIR="$DEST_THEME_CHROMIUM_DIR/win"
if command_exists "convert"; then
    log_info "   ImageMagick 'convert' command found. Creating Windows ICO file..."
    mkdir -p "$DEST_WIN_ICON_DIR"
    convert "$ICONS_DIR/icon_16.png" "$ICONS_DIR/icon_32.png" "$ICONS_DIR/icon_48.png" \
            "$ICONS_DIR/icon_64.png" "$ICONS_DIR/icon_128.png" "$ICONS_DIR/icon_256.png" \
            "$DEST_WIN_ICON_DIR/chromium.ico"
    log_success "✅ Windows ICO file 'chromium.ico' created successfully in '$DEST_WIN_ICON_DIR/'."
else
    log_warn "⚠️ ImageMagick 'convert' command not found. Skipping Windows ICO (chromium.ico) creation."
    log_warn "   Windows builds may lack a proper application icon unless 'chromium.ico' is provided manually."
fi

# Copy favicon to destination
log_info "🖼️ Setting up favicon.png in $HENSURF_ASSETS_DEST_DIR..."
cp "$ICONS_DIR/icon_32.png" "$DEST_THEME_CHROMIUM_DIR/favicon.png"
log_success "✅ Favicon 'favicon.png' setup complete in '$DEST_THEME_CHROMIUM_DIR/'."

# Create chrome_exe.ver for Windows executable branding in destination
DEST_CHROME_EXE_VER_PATH="$DEST_APP_DIR/chrome_exe.ver"
log_info "📝 Creating 'chrome_exe.ver' for Windows executable branding at '$DEST_CHROME_EXE_VER_PATH'..."
cat > "$DEST_CHROME_EXE_VER_PATH" << EOF
// This file defines version strings for the Windows executable.
// It includes chrome_version.rc.version for common fields and overrides others.
#include "chrome/app/chrome_version.rc.version" // Provides defaults like FILE_VERSION, PRODUCT_VERSION

// Override these for HenSurf branding
#undef PRODUCT_FULLNAME_STRING
#define PRODUCT_FULLNAME_STRING     "HenSurf Browser"
#undef PRODUCT_SHORTNAME_STRING
#define PRODUCT_SHORTNAME_STRING    "HenSurf"
// It's also common to override COMPANY_FULLNAME_STRING and COMPANY_SHORTNAME_STRING
#undef COMPANY_FULLNAME_STRING
#define COMPANY_FULLNAME_STRING     "HenSurf Project" // Or your company
#undef COMPANY_SHORTNAME_STRING
#define COMPANY_SHORTNAME_STRING    "HenSurf"
// Copyright string might also be company-specific
#undef COPYRIGHT_STRING
#define COPYRIGHT_STRING            "Copyright 2024 HenSurf Project. All rights reserved."
// InternalName, OriginalFilename, and FileDescription are often overridden too for full branding.
// For example:
// #undef INTERNAL_NAME_STRING
// #define INTERNAL_NAME_STRING        "hensurf.exe"
// #undef ORIGINAL_FILENAME_STRING
// #define ORIGINAL_FILENAME_STRING    "hensurf.exe"
// #undef FILE_DESCRIPTION_STRING
// #define FILE_DESCRIPTION_STRING     "HenSurf Browser"
EOF
log_success "✅ '$DEST_CHROME_EXE_VER_PATH' created."

# Create macOS app icon (app.icns) in destination
HOST_OS_TYPE_FOR_ICNS=$(_get_os_type_internal)
if [[ "$HOST_OS_TYPE_FOR_ICNS" == "macos" ]]; then
    log_info "🍏 Host is macOS. Attempting to create macOS app icon (app.icns)..."
    
    ICONSET_DIR_TEMP="$PROJECT_ROOT/tmp_hensurf_iconset" # Temporary iconset directory
    mkdir -p "$ICONSET_DIR_TEMP"
    log_info "   Creating temporary iconset directory: '$ICONSET_DIR_TEMP'"

    log_info "   Copying icons with '.iconset' naming convention into temp dir..."
    cp "$ICONS_DIR/icon_16.png" "$ICONSET_DIR_TEMP/icon_16x16.png"
    cp "$ICONS_DIR/icon_32.png" "$ICONSET_DIR_TEMP/icon_16x16@2x.png"
    cp "$ICONS_DIR/icon_32.png" "$ICONSET_DIR_TEMP/icon_32x32.png"
    cp "$ICONS_DIR/icon_64.png" "$ICONSET_DIR_TEMP/icon_32x32@2x.png"
    cp "$ICONS_DIR/icon_128.png" "$ICONSET_DIR_TEMP/icon_128x128.png"
    cp "$ICONS_DIR/icon_256.png" "$ICONSET_DIR_TEMP/icon_128x128@2x.png"
    cp "$ICONS_DIR/icon_256.png" "$ICONSET_DIR_TEMP/icon_256x256.png"
    cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR_TEMP/icon_256x256@2x.png"
    cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR_TEMP/icon_512x512.png"
    
    if [ -f "$ICONS_DIR/icon_1024.png" ]; then
        cp "$ICONS_DIR/icon_1024.png" "$ICONSET_DIR_TEMP/icon_512x512@2x.png"
    else
        log_warn "   ⚠️ 'icon_1024.png' not found. Using 'icon_512.png' for 512x512@2x."
        cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR_TEMP/icon_512x512@2x.png"
    fi
    
    # Final app.icns path in the destination directory
    DEST_APP_ICNS_PATH="$DEST_THEME_CHROMIUM_DIR/app.icns"
    if command_exists "iconutil"; then
        log_info "   Generating ICNS file using 'iconutil' to '$DEST_APP_ICNS_PATH'..."
        iconutil -c icns "$ICONSET_DIR_TEMP" -o "$DEST_APP_ICNS_PATH"
        log_success "✅ macOS 'app.icns' created successfully at '$DEST_APP_ICNS_PATH'."
    else
        log_error "❌ 'iconutil' command not found on this macOS host. Cannot create .icns file."
        log_error "   Please ensure Xcode Command Line Tools are installed to use 'iconutil'."
        log_warn "   macOS builds will likely use a default Chromium icon if this asset is not pre-built."
    fi
    
    log_info "   Cleaning up temporary iconset directory: '$ICONSET_DIR_TEMP'..."
    rm -rf "$ICONSET_DIR_TEMP"
    log_success "✅ Temporary iconset directory removed."
else
    log_info "ℹ️ Host OS is not macOS ('$HOST_OS_TYPE_FOR_ICNS'). Skipping macOS 'app.icns' creation."
fi

log_info ""
log_success "🎉 HenSurf logo, icon, and branding assets staged successfully in '$HENSURF_ASSETS_DEST_DIR'!"
log_info "   These assets can now be packaged or used by the build system."

# No longer relevant to cd back as we are not in CHROMIUM_SRC
# safe_cd "$PROJECT_ROOT"
# log_info "Returned to project root: $(pwd)"