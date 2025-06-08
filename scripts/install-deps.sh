#!/bin/bash

# HenSurf Browser - Dependency Installation Script
# This script installs the necessary dependencies for building HenSurf

set -e

echo "🚀 Installing HenSurf build dependencies..."

# OS detection
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Detected macOS"

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

    # Install required packages for macOS
    # Common deps: python3, git, ninja, pkg-config, ccache
    echo "📦 Installing required packages for macOS (python3, git, ninja, pkg-config, ccache)..."
    brew install python3 git ninja pkg-config ccache

    # Install Xcode Command Line Tools if not present
    if ! xcode-select -p &> /dev/null; then
        echo "🔧 Installing Xcode Command Line Tools..."
        xcode-select --install
        echo "⏳ Please complete the Xcode Command Line Tools installation GUI."
        echo "   After installation, re-run this script."
        read -p "Press [Enter] to continue after Xcode Command Line Tools are installed, or Ctrl+C to exit and re-run later."
        if ! xcode-select -p &> /dev/null; then
            echo "❌ Xcode Command Line Tools still not found. Please re-run the script after installation."
            exit 1
        fi
        echo "✅ Xcode Command Line Tools installation detected."
    else
        echo "✅ Xcode Command Line Tools already installed"
    fi

    echo ""
    echo "💡 For optimal performance and to avoid issues, please also consider the following manual steps:"
    echo "   1. Exclude your Chromium/HenSurf checkout directory from Spotlight indexing."
    echo "      (System Settings -> Siri & Spotlight -> Spotlight Privacy... -> Add your checkout folder)"
    echo "   2. Ensure the Xcode license agreement is accepted by running in your terminal:"
    echo "      sudo xcodebuild -license accept"
    echo ""
    read -p "Press [Enter] to acknowledge these recommendations and continue..."

elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    echo "💻 Detected Windows"

    # Python
    echo "🐍 Checking for Python..."
    PYTHON_CMD=""
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    fi

    if [ -z "$PYTHON_CMD" ]; then
        echo "❌ Python not found. Please install Python 3.8 or newer."
        echo "   Visit https://www.python.org/downloads/windows/"
        echo "   Alternatively, using Chocolatey: choco install python"
        exit 1
    else
        # Python version check logic will be handled later by the common check
        echo "✅ Python command detected ($PYTHON_CMD)."
    fi

    # Git (assumed if running in Git Bash, but good to mention)
    echo "🌐 Checking for Git..."
    if ! command -v git &> /dev/null; then
        echo "❌ Git not found. Please install Git for Windows."
        echo "   Visit https://git-scm.com/download/win"
        echo "   This script requires Git to be in PATH, especially for depot_tools."
        exit 1
    else
        echo "✅ Git found."
    fi

    # Ninja
    echo "🥷 Checking for Ninja..."
    if ! command -v ninja &> /dev/null; then
        echo "❌ Ninja not found. Please install Ninja."
        echo "   Using Chocolatey: choco install ninja"
        echo "   Or download from https://github.com/ninja-build/ninja/releases and add to PATH."
        # Unlike other checks, for Ninja we might not want to exit immediately,
        # as depot_tools might fetch its own version.
        # However, having it pre-installed is generally better.
        # For now, we'll make it a strong recommendation rather than a hard exit.
        echo "   Continuing, but build may fail if Ninja is not made available via depot_tools or system PATH."
    else
        echo "✅ Ninja found."
    fi

    # Visual Studio Build Tools
    echo "🔧 Visual Studio Build Tools:"
    echo "   Please ensure you have Visual Studio C++ Build Tools installed."
    echo "   Required: 'Desktop development with C++' workload."
    echo "   Recommended: Visual Studio 2019 (e.g., v16.11.14+) or Visual Studio 2022."
    echo "   Chromium's gclient hooks may attempt to manage this if specific environment variables are set (e.g., DEPOT_TOOLS_WIN_TOOLCHAIN=0)."
    echo "   If you have issues, ensure VS is correctly installed and discoverable by depot_tools."
    echo "   Press [Enter] to acknowledge and continue."
    read -r

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🐧 Detected Linux"
    if command -v apt-get &> /dev/null; then
        echo "Distro: Debian/Ubuntu (apt package manager found)"
        echo "📦 Installing dependencies for Debian/Ubuntu..."
        sudo apt-get update
        sudo apt-get install -y python3 git ninja-build pkg-config build-essential libgtk-3-dev libnss3-dev libasound2-dev libcups2-dev libxtst-dev libxss1 libatk1.0-dev libatk-bridge2.0-dev libdrm-dev libgbm-dev libx11-xcb-dev uuid-dev
    elif command -v dnf &> /dev/null; then
        echo "Distro: Fedora (dnf package manager found)"
        echo "📦 Installing dependencies for Fedora..."
        sudo dnf install -y python3 git ninja-build pkgconf-pkg-config gcc-c++ gtk3-devel nss-devel alsa-lib-devel cups-devel libXtst-devel libXScrnSaver-devel atk-devel at-spi2-atk-devel libdrm-devel libgbm-devel libX11-xcb-devel libuuid-devel
    elif command -v pacman &> /dev/null; then
        echo "Distro: Arch Linux (pacman package manager found)"
        echo "📦 Installing dependencies for Arch Linux..."
        sudo pacman -Syu --noconfirm --needed base-devel python git ninja pkgconf gtk3 nss alsa-lib cups libxtst libxscrnsaver libatk at-spi2-atk libdrm libgbm libx11 libxcb util-linux
    else
        echo "❌ Unsupported Linux distribution or package manager not found."
        echo "Please install the following dependencies manually:"
        echo "  python3, git, ninja-build (or ninja), pkg-config, gcc/g++ (build-essential),"
        echo "  libgtk-3-dev, libnss3-dev, libasound2-dev, libcups2-dev, libxtst-dev,"
        echo "  libxss1 (or libxscrnsaver), libatk1.0-dev, libatk-bridge2.0-dev, libdrm-dev, libgbm-dev,"
        echo "  libx11-xcb-dev, uuid-dev (or libuuid-devel or util-linux for uuidgen)"
        exit 1
    fi
else
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi

# Check Python version (common logic for macOS, Linux, and Windows)
echo "🐍 Checking Python version..."
# PYTHON_CMD should be set by OS-specific block for Windows
if [[ -z "$PYTHON_CMD" ]]; then # If not set by Windows block, means it's Linux/macOS
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        echo "❌ Python not found. Please install Python 3.8 or newer."
        # For Windows, specific instructions were already given.
        if ! ([[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]); then
            echo "   On macOS: brew install python"
            echo "   On Linux: sudo apt-get install python3 (or equivalent for your distro)"
        fi
        exit 1
    fi
fi

# Check if PYTHON_CMD is valid
if ! command -v $PYTHON_CMD &> /dev/null; then
    echo "❌ Python command '$PYTHON_CMD' not found after OS detection. This is an internal script error."
    exit 1
fi

PYTHON_VERSION_FULL=$($PYTHON_CMD --version 2>&1)
PYTHON_VERSION=$(echo "$PYTHON_VERSION_FULL" | cut -d' ' -f2 | cut -d'.' -f1,2)
REQUIRED_MAJOR=3
REQUIRED_MINOR=8

CURRENT_MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
CURRENT_MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

if [ "$CURRENT_MAJOR" -lt "$REQUIRED_MAJOR" ] || { [ "$CURRENT_MAJOR" -eq "$REQUIRED_MAJOR" ] && [ "$CURRENT_MINOR" -lt "$REQUIRED_MINOR" ]; }; then
    echo "❌ Python version $PYTHON_VERSION ($PYTHON_VERSION_FULL) is too old."
    echo "   Please install Python $REQUIRED_MAJOR.$REQUIRED_MINOR or newer."
    echo "   Found at: $($PYTHON_CMD -c 'import sys; print(sys.executable)')"
    exit 1
else
    echo "✅ Python $PYTHON_VERSION ($PYTHON_VERSION_FULL) is compatible (found at $($PYTHON_CMD -c 'import sys; print(sys.executable)'))"
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)
PARENT_OF_PROJECT_ROOT=$(cd "$PROJECT_ROOT/.." &>/dev/null && pwd)
DEPOT_TOOLS_DIR="$PARENT_OF_PROJECT_ROOT/depot_tools"

if [ ! -d "$DEPOT_TOOLS_DIR" ]; then
    echo "📦 Downloading depot_tools into $PARENT_OF_PROJECT_ROOT..."

    ORIGINAL_PWD=$(pwd)
    echo "Changing directory to $PARENT_OF_PROJECT_ROOT for cloning depot_tools."
    cd "$PARENT_OF_PROJECT_ROOT"
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    echo "Changing directory back to $ORIGINAL_PWD."
    cd "$ORIGINAL_PWD"
else
    echo "✅ depot_tools already exists at $DEPOT_TOOLS_DIR"
fi

# Setting PATH for depot_tools
# For Windows (msys/cygwin), the export syntax is fine.
# If this script were to be a .bat file, this would be 'set PATH=%DEPOT_TOOLS_DIR%;%PATH%'
export PATH="$DEPOT_TOOLS_DIR:$PATH"
echo "🔧 Added depot_tools to PATH for this session: $DEPOT_TOOLS_DIR"

if [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    echo "   (Note: This PATH change is only for the current Git Bash/MSYS session.)"
    echo "✅ All core dependencies checked for Windows!"
else
    echo "   (Note: This PATH change is only for the current terminal session.)"
    echo "✅ All core dependencies installed and depot_tools configured for this session!"
fi

echo ""
echo "Next steps:"
if [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    echo "1. IMPORTANT: Add depot_tools to your Windows PATH environment variable permanently if you haven't already."
    echo "   You can do this through 'Environment Variables' settings in Windows, or by using 'setx' command in cmd.exe (e.g., setx PATH \"%PATH%;$DEPOT_TOOLS_DIR\")."
    echo "   Restart your Git Bash/MSYS terminal after making permanent changes."
else
    echo "1. IMPORTANT: Add depot_tools to your shell's startup file (e.g., ~/.bashrc, ~/.zshrc) if you haven't already:"
    echo "   echo 'export PATH=\"$DEPOT_TOOLS_DIR:\$PATH\"' >> ~/.your_shell_rc_file"
    echo "   Then, source the file (e.g., source ~/.bashrc) or open a new terminal."
fi
echo "2. Run ./scripts/fetch-chromium.sh to download Chromium source (will use depot_tools from PATH)."
echo "3. Run ./scripts/apply-patches.sh to apply HenSurf customizations."
echo "4. Run ./scripts/build.sh to build HenSurf."
echo ""
echo "⚠️  Note: The full Chromium build process requires significant disk space (~100GB) and can take several hours."