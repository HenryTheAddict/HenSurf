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
# CHROMIUM_SRC is the path to the 'src' directory within the Chromium checkout.
CHROMIUM_SRC="$PROJECT_ROOT/chromium/src"
# BRANDING_DIR contains the HenSurf branding assets (icons, BRANDING file).
BRANDING_DIR="$PROJECT_ROOT/branding"
# ICONS_DIR is where processed PNG icons are stored.
ICONS_DIR="$BRANDING_DIR/icons"

log_info "🎨 Setting up HenSurf logo, icons, and branding files..."

# --- Pre-flight Checks ---
log_info "🔎 Performing pre-flight checks..."
if [ ! -d "$CHROMIUM_SRC" ]; then
    log_error "❌ Chromium source directory not found at '$CHROMIUM_SRC'."
    log_error "   Please ensure Chromium has been fetched by running './scripts/fetch-chromium.sh' first."
    exit 1
fi
log_success "✅ Chromium source directory found: $CHROMIUM_SRC"

if [ ! -d "$ICONS_DIR" ]; then
    log_error "❌ Icons directory not found at '$ICONS_DIR'."
    log_error "   This directory should contain pre-processed PNG icons (icon_16.png, icon_32.png, etc.)."
    log_error "   Ensure branding assets are correctly placed in '$BRANDING_DIR/icons/'."
    exit 1
fi
log_success "✅ Icons directory found: $ICONS_DIR"

# --- Main Setup Logic ---

# Navigate to Chromium source directory for all file operations
safe_cd "$CHROMIUM_SRC"
log_info "Working inside Chromium source directory: $(pwd)"

# Define target theme directories within chromium/src
# These are standard Chromium directories for placing theme assets.
THEME_MAIN_DIR="chrome/app/theme" # Base theme directory
THEME_CHROMIUM_DIR="$THEME_MAIN_DIR/chromium" # For general chromium assets
THEME_HENSURF_DIR="$THEME_MAIN_DIR/hensurf"   # HenSurf specific branding (e.g., BRANDING file)
THEME_100_PERCENT_DIR="$THEME_MAIN_DIR/default_100_percent/chromium" # For 100% scale assets
THEME_200_PERCENT_DIR="$THEME_MAIN_DIR/default_200_percent/chromium" # For 200% scale assets (Retina)

# Create necessary theme directories if they don't exist
log_info "🔧 Ensuring theme directories exist..."
mkdir -p "$THEME_CHROMIUM_DIR"
mkdir -p "$THEME_HENSURF_DIR"
mkdir -p "$THEME_100_PERCENT_DIR"
mkdir -p "$THEME_200_PERCENT_DIR"
log_success "✅ Theme directories ensured."

# Copy HenSurf BRANDING file
log_info "🏷️ Copying HenSurf BRANDING file..."
if [ -f "$BRANDING_DIR/BRANDING" ]; then
    cp "$BRANDING_DIR/BRANDING" "$THEME_HENSURF_DIR/BRANDING"
    log_success "✅ BRANDING file copied to '$THEME_HENSURF_DIR/BRANDING'."
else
    log_warn "⚠️ BRANDING file not found at '$BRANDING_DIR/BRANDING'. Skipping copy."
fi

# Copy standard resolution PNG icons
log_info "🖼️ Copying standard resolution PNG icons..."
cp "$ICONS_DIR/icon_16.png" "$THEME_CHROMIUM_DIR/product_logo_16.png"
cp "$ICONS_DIR/icon_32.png" "$THEME_CHROMIUM_DIR/product_logo_32.png"
cp "$ICONS_DIR/icon_48.png" "$THEME_100_PERCENT_DIR/product_logo_48.png" # Note: 48px goes to default_100_percent
cp "$ICONS_DIR/icon_64.png" "$THEME_CHROMIUM_DIR/product_logo_64.png"
cp "$ICONS_DIR/icon_128.png" "$THEME_CHROMIUM_DIR/product_logo_128.png"
cp "$ICONS_DIR/icon_256.png" "$THEME_CHROMIUM_DIR/product_logo_256.png"
log_success "✅ Standard resolution icons copied."

# Copy high-resolution (200%) PNG icons for Retina displays
log_info "🖼️ Copying high-resolution (200%) PNG icons..."
cp "$ICONS_DIR/icon_32.png" "$THEME_200_PERCENT_DIR/product_logo_16.png"  # 16px@2x = 32px
cp "$ICONS_DIR/icon_64.png" "$THEME_200_PERCENT_DIR/product_logo_32.png"  # 32px@2x = 64px

# Specific handling for product_logo_48.png at 200% (expects 96px actual size)
TARGET_48_200_PATH="$THEME_200_PERCENT_DIR/product_logo_48.png"
if [ -f "$ICONS_DIR/icon_96.png" ]; then
    cp "$ICONS_DIR/icon_96.png" "$TARGET_48_200_PATH"
    log_info "   Copied icon_96.png for 48px@200%."
elif [ -f "$ICONS_DIR/icon_128.png" ]; then # Fallback to 128 if 96 is not available
    cp "$ICONS_DIR/icon_128.png" "$TARGET_48_200_PATH"
    log_warn "   ⚠️ Icon 'icon_96.png' not found. Used 'icon_128.png' as fallback for 48px@200%."
else
    log_error "❌ Missing suitable icon for 48px@200% (expected 'icon_96.png' or 'icon_128.png')."
    # This might not be fatal, depending on build strictness.
fi
log_success "✅ High-resolution icons copied."

# Create Windows ICO file (chrome.ico)
log_info "🖼️ Preparing Windows ICO file (chrome.ico)..."
if command_exists "convert"; then
    log_info "   ImageMagick 'convert' command found. Creating Windows ICO file..."
    # ICO files typically include multiple sizes.
    convert "$ICONS_DIR/icon_16.png" "$ICONS_DIR/icon_32.png" "$ICONS_DIR/icon_48.png" \
            "$ICONS_DIR/icon_64.png" "$ICONS_DIR/icon_128.png" "$ICONS_DIR/icon_256.png" \
            "$THEME_MAIN_DIR/chrome.ico" # Place in chrome/app/theme/
    log_success "✅ Windows ICO file 'chrome.ico' created successfully in '$THEME_MAIN_DIR/'."
else
    log_warn "⚠️ ImageMagick 'convert' command not found. Skipping Windows ICO (chrome.ico) creation."
    log_warn "   Windows builds may lack a proper application icon unless 'chrome.ico' is provided manually."
fi

# Copy favicon (used in some UI elements or as fallback)
log_info "🖼️ Setting up favicon.png..."
cp "$ICONS_DIR/icon_32.png" "$THEME_CHROMIUM_DIR/favicon.png"
log_success "✅ Favicon 'favicon.png' setup complete in '$THEME_CHROMIUM_DIR/'."

# Update/Create chrome_exe.ver for Windows executable branding
log_info "📝 Updating/Creating 'chrome/app/chrome_exe.ver' for Windows executable branding..."
CHROME_EXE_VER_PATH="chrome/app/chrome_exe.ver" # Relative to $CHROMIUM_SRC
cat > "$CHROME_EXE_VER_PATH" << EOF
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
log_success "✅ '$CHROME_EXE_VER_PATH' updated/created."

# Create macOS app icon (app.icns)
# This section should run if the HOST is macOS, as iconutil is a macOS tool.
# The actual usage of app.icns is when building FOR macOS.
HOST_OS_TYPE_FOR_ICNS=$(_get_os_type_internal) # Get generic host OS type
if [[ "$HOST_OS_TYPE_FOR_ICNS" == "macos" ]]; then
    log_info "🍏 Host is macOS. Attempting to create macOS app icon (app.icns)..."

    # Define iconset directory (temporary)
    ICONSET_DIR_REL="chrome/app/theme/app.iconset" # Relative to $CHROMIUM_SRC
    ICONSET_DIR_ABS="$CHROMIUM_SRC/$ICONSET_DIR_REL"
    # Define final app.icns path
    APP_ICNS_PATH_REL="chrome/app/theme/chromium/app.icns" # Standard location Chromium looks for
    APP_ICNS_PATH_ABS="$CHROMIUM_SRC/$APP_ICNS_PATH_REL"

    log_info "   Creating temporary iconset directory: '$ICONSET_DIR_ABS'"
    mkdir -p "$ICONSET_DIR_ABS" # Corrected ICONSET_DIR to ICONSET_DIR_ABS

    # The following mkdir was redundant as the one above creates it.
    # log_info "Copying icons with proper naming for iconset..."
    # mkdir -p "$ICONSET_DIR_ABS"
    
    log_info "   Copying icons with '.iconset' naming convention..."
    cp "$ICONS_DIR/icon_16.png" "$ICONSET_DIR_ABS/icon_16x16.png"
    cp "$ICONS_DIR/icon_32.png" "$ICONSET_DIR_ABS/icon_16x16@2x.png"
    cp "$ICONS_DIR/icon_32.png" "$ICONSET_DIR_ABS/icon_32x32.png"
    cp "$ICONS_DIR/icon_64.png" "$ICONSET_DIR_ABS/icon_32x32@2x.png"
    cp "$ICONS_DIR/icon_128.png" "$ICONSET_DIR_ABS/icon_128x128.png"
    cp "$ICONS_DIR/icon_256.png" "$ICONSET_DIR_ABS/icon_128x128@2x.png"
    cp "$ICONS_DIR/icon_256.png" "$ICONSET_DIR_ABS/icon_256x256.png"
    cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR_ABS/icon_256x256@2x.png"
    cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR_ABS/icon_512x512.png"
    
    # For 512x512@2x, a 1024px image is ideal. Use 512px as fallback.
    if [ -f "$ICONS_DIR/icon_1024.png" ]; then
        cp "$ICONS_DIR/icon_1024.png" "$ICONSET_DIR_ABS/icon_512x512@2x.png"
    else
        log_warn "   ⚠️ 'icon_1024.png' not found. Using 'icon_512.png' for 512x512@2x. This might result in a lower resolution for the largest icon size on Retina displays."
        cp "$ICONS_DIR/icon_512.png" "$ICONSET_DIR_ABS/icon_512x512@2x.png"
    fi
    
    if command_exists "iconutil"; then
        log_info "   Generating ICNS file using 'iconutil' to '$APP_ICNS_PATH_ABS'..."
        iconutil -c icns "$ICONSET_DIR_ABS" -o "$APP_ICNS_PATH_ABS"
        log_success "✅ macOS 'app.icns' created successfully at '$APP_ICNS_PATH_REL'."
    else
        log_error "❌ 'iconutil' command not found on this macOS host. Cannot create .icns file."
        log_error "   Please ensure Xcode Command Line Tools are installed to use 'iconutil'."
        log_warn "   macOS builds will likely use a default Chromium icon."
    fi
    
    log_info "   Cleaning up temporary iconset directory: '$ICONSET_DIR_ABS'..."
    rm -rf "$ICONSET_DIR_ABS"
    log_success "✅ Temporary iconset directory removed."
else
    log_info "ℹ️ Host OS is not macOS ('$HOST_OS_TYPE_FOR_ICNS'). Skipping macOS 'app.icns' creation. This is normal if not building on a Mac."
fi

log_info ""
log_success "🎉 HenSurf logo, icon, and branding file setup completed successfully!"
log_info "   Static branding assets have been placed into the Chromium source tree."
log_info "   The build process should now pick up these assets for the final application."

# Return to original directory if this script was called from somewhere else.
# safe_cd was used to go into CHROMIUM_SRC, so this ensures we are back where we started if needed.
# However, since this script is usually called by apply-patches.sh which manages its own CWD,
# this might be redundant, but good practice for a standalone script.
# safe_cd "$PROJECT_ROOT"
# log_info "Returned to project root: $(pwd)"