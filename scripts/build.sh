#!/bin/bash

# HenSurf Browser - Build Script
# This script builds HenSurf from the customized Chromium source

set -e

echo "🔨 Building HenSurf Browser..."

# Check if Chromium source exists
if [ ! -d "chromium/src" ]; then
    echo "❌ Chromium source not found. Please run ./scripts/fetch-chromium.sh first."
    exit 1
fi

# Check if patches have been applied
if [ ! -f "chromium/src/out/HenSurf/args.gn" ]; then
    echo "❌ HenSurf configuration not found. Please run ./scripts/apply-patches.sh first."
    exit 1
fi

# Add depot_tools to PATH
# Corrected path: install-deps.sh places depot_tools alongside the project root (e.g. ../depot_tools if project is HenSurf)
# This script cds into chromium/src, so from there, depot_tools is ../../depot_tools

cd chromium/src

# IMPORTANT: Set path to depot_tools, assuming it's two levels up from chromium/src
# e.g. if project is /path/to/HenSurf, depot_tools is /path/to/depot_tools
# and current dir is /path/to/HenSurf/chromium/src
export PATH="$PWD/../../depot_tools:$PATH"


# Check system requirements
echo "🔍 Checking system requirements..."

MEMORY_GB=0
CPU_CORES=1 # Default to 1 core if detection fails

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍏 Checking macOS system requirements..."
    MEMORY_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    CPU_CORES=$(sysctl -n hw.ncpu)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🐧 Checking Linux system requirements..."
    if [ -f /proc/meminfo ]; then
        MEMORY_GB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
    else
        echo "⚠️ Could not read /proc/meminfo to determine system memory."
    fi
    if command -v nproc &> /dev/null; then
        CPU_CORES=$(nproc)
    else
        echo "⚠️ nproc command not found, defaulting to 1 CPU core for estimates."
    fi
else
    echo "⚠️ Unsupported OS ($OSTYPE) for detailed system checks. Proceeding with default assumptions (0GB RAM, 1 CPU core)."
fi

if [ "$MEMORY_GB" -lt 16 ]; then
    if [ "$MEMORY_GB" -gt 0 ]; then # Only warn if we got a valid reading
        echo "⚠️  Warning: Only ${MEMORY_GB}GB RAM detected. 16GB+ recommended for building."
    else
        echo "⚠️  Warning: Could not determine system RAM. 16GB+ recommended for building."
    fi
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check available disk space (seems OS-agnostic enough)
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/[^0-9.]//g') # More robust sed
if [ "$AVAILABLE_SPACE" -lt 50 ]; then
    echo "⚠️  Warning: Less than 50GB available. Build requires ~50GB additional space."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Generate build files
echo "⚙️  Generating build files..."
gn gen out/HenSurf

if [ $? -ne 0 ]; then
    echo "❌ Failed to generate build files. Check the configuration."
    exit 1
fi

# Show build configuration
echo "📋 Build configuration:"
gn args out/HenSurf --list --short

# Estimate build time
# CPU_CORES is now determined OS-specifically above
ESTIMATED_HOURS=$((8 / CPU_CORES))
if [ "$ESTIMATED_HOURS" -lt 1 ]; then
    ESTIMATED_HOURS=1
fi

echo ""
echo "🚀 Starting HenSurf build..."
echo "📊 System info:"
echo "   CPU cores: $CPU_CORES"
echo "   Memory: ${MEMORY_GB}GB"
echo "   Estimated time: ~${ESTIMATED_HOURS} hours"
echo ""
echo "⏳ This will take a while. You can monitor progress in another terminal with:"
echo "   tail -f chromium/src/out/HenSurf/build.log"
echo ""

# Start the build with logging
echo "$(date): Starting HenSurf build" > out/HenSurf/build.log

# Build HenSurf (chrome target)
echo "🔨 Building HenSurf browser..."
autoninja -C out/HenSurf chrome 2>&1 | tee -a out/HenSurf/build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ Build failed. Check out/HenSurf/build.log for details."
    exit 1
fi

# Build additional components
echo "🔨 Building additional components..."
autoninja -C out/HenSurf chromedriver 2>&1 | tee -a out/HenSurf/build.log

# Create application bundle for macOS (and build macOS installer)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📦 Creating macOS application bundle..."
    if [ -d "out/HenSurf/HenSurf.app" ]; then
        rm -rf out/HenSurf/HenSurf.app
    fi

    # Copy and rename the Chrome app bundle
    # Try common names for the output app bundle from Chromium build
    CHROME_APP_NAMES=( "Chromium.app" "Google Chrome.app" "Chrome.app" )
    APP_COPIED=false
    for app_name in "${CHROME_APP_NAMES[@]}"; do
        if [ -d "out/HenSurf/${app_name}" ]; then
            echo "Found ${app_name}, copying to HenSurf.app..."
            cp -R "out/HenSurf/${app_name}" "out/HenSurf/HenSurf.app"
            APP_COPIED=true
            break
        fi
    done

    if [ "$APP_COPIED" = true ] && [ -d "out/HenSurf/HenSurf.app" ]; then
        # Update Info.plist
        PLIST_BUDDY="/usr/libexec/PlistBuddy"
        INFO_PLIST="out/HenSurf/HenSurf.app/Contents/Info.plist"
        if [ -f "$PLIST_BUDDY" ] && [ -f "$INFO_PLIST" ]; then
            "$PLIST_BUDDY" -c "Set :CFBundleName HenSurf" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleName"
            "$PLIST_BUDDY" -c "Set :CFBundleDisplayName HenSurf Browser" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleDisplayName"
            "$PLIST_BUDDY" -c "Set :CFBundleIdentifier com.hensurf.browser" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleIdentifier"
            echo "✅ HenSurf.app created and configured successfully!"
        else
            echo "⚠️  PlistBuddy or Info.plist not found. Cannot customize app bundle."
        fi
    else
        echo "⚠️  Could not find a base Chrome app bundle (Chromium.app, Google Chrome.app, or Chrome.app) in out/HenSurf/ to create HenSurf.app."
        echo "   The raw 'chrome' binary should still be available."
    fi

    # Build macOS installer (optional)
    echo "📦 Building macOS installer (dmg)..."
    autoninja -C out/HenSurf mini_installer 2>&1 | tee -a out/HenSurf/build.log || echo "ℹ️  macOS installer build step finished (may have warnings or be skipped)."

fi # End of macOS specific bundling

echo ""
echo "🎉 HenSurf build completed successfully!"
echo ""
echo "📍 Build artifacts location (relative to chromium/src):"
echo "   Main executable: out/HenSurf/chrome"
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "out/HenSurf/HenSurf.app" ]; then
        echo "   macOS App Bundle: out/HenSurf/HenSurf.app"
    fi
    if [ -f "out/HenSurf/HenSurf.dmg" ]; then # Assuming mini_installer produces HenSurf.dmg
        echo "   macOS Installer:  out/HenSurf/HenSurf.dmg"
    fi
fi
echo "   Build log: out/HenSurf/build.log"
echo ""
echo "🚀 To run HenSurf (from chromium/src directory):"
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "out/HenSurf/HenSurf.app" ]; then
        echo "   open out/HenSurf/HenSurf.app"
    else
        echo "   ./out/HenSurf/chrome  (App bundle creation failed or was skipped)"
    fi
else # For Linux and other OSes
    echo "   ./out/HenSurf/chrome"
fi
echo ""
echo "📋 HenSurf features:"
echo "   ✅ No AI-powered suggestions"
echo "   ✅ No Google services integration"
echo "   ✅ DuckDuckGo as default search"
echo "   ✅ Enhanced privacy settings"
echo "   ✅ Minimal telemetry"
echo "   ✅ Clean, bloatware-free interface"