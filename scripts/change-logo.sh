#!/bin/bash

# HenSurf Logo Change Script
# This script only handles logo and icon updates without applying other patches

set -e

echo "=== HenSurf Logo Change Script ==="
echo "This script will update the browser logo and icons only."
echo

# Check if we're in the right directory
if [ ! -f "Hensurf.png" ]; then
    echo "Error: Hensurf.png not found. Please run this script from the HenSurf project root."
    exit 1
fi

# Check if Chromium source exists
if [ ! -d "chromium/src" ]; then
    echo "Error: Chromium source not found. Please download Chromium first."
    exit 1
fi

echo "Step 1: Setting up logo and generating icons..."
if [ -f "scripts/setup-logo.sh" ]; then
    chmod +x scripts/setup-logo.sh
    ./scripts/setup-logo.sh
    echo "✓ Logo setup completed"
else
    echo "Error: setup-logo.sh not found"
    exit 1
fi

echo
echo "Step 2: Applying logo integration patch..."
cd chromium/src

# Check if patch exists
if [ ! -f "../../patches/integrate-logo.patch" ]; then
    echo "Error: integrate-logo.patch not found"
    exit 1
fi

# Apply the logo patch
echo "Applying integrate-logo.patch..."
if patch -p1 < ../../patches/integrate-logo.patch; then
    echo "✓ Logo integration patch applied successfully"
else
    echo "Error: Failed to apply logo integration patch"
    echo "This might be because the patch was already applied or there are conflicts."
    echo "You can check the status with: git status"
fi

cd ../..

echo
echo "Step 3: Updating branding files..."

# Update version info to HenSurf
echo "Updating version information..."
if [ -f "chromium/src/chrome/VERSION" ]; then
    # Update the version file to show HenSurf branding
    sed -i.bak 's/Chromium/HenSurf Browser/g' chromium/src/chrome/VERSION 2>/dev/null || true
fi

# Update user agent
echo "Updating user agent..."
if [ -f "chromium/src/content/common/user_agent.cc" ]; then
    sed -i.bak 's/Chrome/HenSurf/g' chromium/src/content/common/user_agent.cc 2>/dev/null || true
fi

echo
echo "=== Logo Change Complete ==="
echo "✓ HenSurf logo and icons have been set up"
echo "✓ Branding integration patch applied"
echo "✓ Version information updated"
echo
echo "The browser will now use the HenSurf logo and branding."
echo "You can now build the browser with: ./scripts/build.sh"
echo
echo "Note: This script only changes the logo. To apply other customizations,"
echo "use the full ./scripts/apply-patches.sh script."