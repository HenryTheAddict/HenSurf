#!/bin/bash

# HenSurf Browser - Dependency Installation Script
# This script installs the necessary dependencies for building HenSurf

set -e

echo "🚀 Installing HenSurf build dependencies..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script is designed for macOS only."
    exit 1
fi

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✅ Homebrew already installed"
fi

# Update Homebrew
echo "🔄 Updating Homebrew..."
brew update

# Install required packages
echo "📦 Installing required packages..."
brew install python3 git ninja

# Install Xcode Command Line Tools if not present
if ! xcode-select -p &> /dev/null; then
    echo "🔧 Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "⚠️  Please complete the Xcode Command Line Tools installation and run this script again."
    exit 1
else
    echo "✅ Xcode Command Line Tools already installed"
fi

# Check Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_VERSION="3.8"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
    echo "✅ Python $PYTHON_VERSION is compatible"
else
    echo "❌ Python $PYTHON_VERSION is too old. Please install Python 3.8 or newer."
    exit 1
fi

# Create depot_tools directory if it doesn't exist
if [ ! -d "../depot_tools" ]; then
    echo "📦 Downloading depot_tools..."
    cd ..
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    cd HenSurf
else
    echo "✅ depot_tools already exists"
fi

# Add depot_tools to PATH for this session
export PATH="$PWD/../depot_tools:$PATH"

echo "✅ All dependencies installed successfully!"
echo ""
echo "Next steps:"
echo "1. Run ./scripts/fetch-chromium.sh to download Chromium source"
echo "2. Run ./scripts/apply-patches.sh to apply HenSurf customizations"
echo "3. Run ./scripts/build.sh to build HenSurf"
echo ""
echo "⚠️  Note: The full build process requires ~100GB of disk space and several hours."