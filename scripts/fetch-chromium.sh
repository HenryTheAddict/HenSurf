#!/bin/bash

# HenSurf Browser - Chromium Source Fetch Script
# This script downloads the Chromium source code

set -e

echo "🌐 Fetching Chromium source code for HenSurf..."

# Check if depot_tools exists
if [ ! -d "../depot_tools" ]; then
    echo "❌ depot_tools not found. Please run ./scripts/install-deps.sh first."
    exit 1
fi

# Add depot_tools to PATH
export PATH="$PWD/../depot_tools:$PATH"

# Check available disk space (need at least 100GB)
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 100 ]; then
    echo "⚠️  Warning: Less than 100GB available. Chromium source requires ~100GB."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create chromium directory if it doesn't exist
if [ ! -d "chromium" ]; then
    echo "📁 Creating chromium directory..."
    mkdir chromium
fi

cd chromium

# Check if .gclient exists (indicates previous fetch)
if [ -f ".gclient" ]; then
    echo "🔄 Updating existing Chromium source..."
    gclient sync
else
    echo "📦 Fetching Chromium source (this will take a while)..."
    echo "⏳ Expected time: 30-60 minutes depending on internet speed"
    
    # Fetch Chromium source
    fetch --nohooks chromium
    
    echo "🔧 Running gclient hooks..."
    cd src
    gclient runhooks
    cd ..
fi

echo "✅ Chromium source code ready!"
echo ""
echo "Next steps:"
echo "1. Run ./scripts/apply-patches.sh to apply HenSurf customizations"
echo "2. Run ./scripts/build.sh to build HenSurf"