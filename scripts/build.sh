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
export PATH="$PWD/../depot_tools:$PATH"

cd chromium/src

# Check system requirements
echo "🔍 Checking system requirements..."

# Check available memory (recommend 16GB+)
MEMORY_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
if [ "$MEMORY_GB" -lt 16 ]; then
    echo "⚠️  Warning: Only ${MEMORY_GB}GB RAM detected. 16GB+ recommended for building."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check available disk space
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
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
CPU_CORES=$(sysctl -n hw.ncpu)
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

# Create application bundle for macOS
echo "📦 Creating macOS application bundle..."
if [ -d "out/HenSurf/HenSurf.app" ]; then
    rm -rf out/HenSurf/HenSurf.app
fi

# Copy and rename the Chrome app bundle
cp -R out/HenSurf/Chromium.app out/HenSurf/HenSurf.app 2>/dev/null || \
cp -R out/HenSurf/Google\ Chrome.app out/HenSurf/HenSurf.app 2>/dev/null || \
cp -R out/HenSurf/Chrome.app out/HenSurf/HenSurf.app 2>/dev/null || true

if [ -d "out/HenSurf/HenSurf.app" ]; then
    # Update Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleName HenSurf" out/HenSurf/HenSurf.app/Contents/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName HenSurf Browser" out/HenSurf/HenSurf.app/Contents/Info.plist 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.hensurf.browser" out/HenSurf/HenSurf.app/Contents/Info.plist 2>/dev/null || true
    
    echo "✅ HenSurf.app created successfully!"
else
    echo "⚠️  Could not create app bundle, but binary should be available"
fi

# Build installer (optional)
echo "📦 Building installer..."
autoninja -C out/HenSurf chrome/installer/mac 2>&1 | tee -a out/HenSurf/build.log || true

echo ""
echo "🎉 HenSurf build completed successfully!"
echo ""
echo "📍 Build artifacts location:"
echo "   Binary: chromium/src/out/HenSurf/chrome"
if [ -d "out/HenSurf/HenSurf.app" ]; then
    echo "   App Bundle: chromium/src/out/HenSurf/HenSurf.app"
fi
echo "   Build log: chromium/src/out/HenSurf/build.log"
echo ""
echo "🚀 To run HenSurf:"
if [ -d "out/HenSurf/HenSurf.app" ]; then
    echo "   open out/HenSurf/HenSurf.app"
else
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