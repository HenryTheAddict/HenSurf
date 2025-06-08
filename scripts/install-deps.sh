#!/bin/bash

# HenSurf Browser - Dependency Installation Script
# This script installs the necessary dependencies for building HenSurf

set -e

# Source utility functions
SCRIPT_DIR_REAL_INSTALL_DEPS=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR_REAL_INSTALL_DEPS/utils.sh"

log_info "🚀 Installing HenSurf build dependencies..."

# Define Project Root early as it's used by some functions or for clarity
PROJECT_ROOT=$(cd "$SCRIPT_DIR_REAL_INSTALL_DEPS/.." &>/dev/null && pwd)

# OS detection
OS_TYPE=$(get_os_type)
case "$OS_TYPE" in
    "macos")
        log_info "🍎 Detected macOS"

        # Check if Homebrew is installed
        if ! command_exists "brew"; then
            log_info "📦 Installing Homebrew..."
            if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
                log_error "Homebrew installation failed. Please install it manually and re-run."
                exit 1
            fi
        else
            log_success "✅ Homebrew already installed"
        fi

        # Update Homebrew
        log_info "🔄 Updating Homebrew..."
        if ! brew update; then
            log_warn "Brew update failed. Continuing, but package installation might use outdated formulae."
        fi

        # Install required packages for macOS
        log_info "📦 Installing required packages for macOS (python3, git, ninja, pkg-config, ccache)..."
        if ! brew install python3 git ninja pkg-config ccache; then
            log_error "Failed to install one or more Homebrew packages. Please check brew's output."
            exit 1
        fi
        log_success "✅ Successfully installed Homebrew packages."


        # Install Xcode Command Line Tools if not present
        if ! command_exists "xcode-select"; then
            log_error "xcode-select command not found. This is unexpected on macOS."
            log_info "Attempting to install Xcode Command Line Tools, but you might need to install Xcode from the App Store first."
        fi

        if ! xcode-select -p &> /dev/null; then
            log_info "🔧 Installing Xcode Command Line Tools..."
            xcode-select --install
            log_info "⏳ Please complete the Xcode Command Line Tools installation GUI if it appears."
            log_info "   After installation, you may need to re-run this script."
            read -r -p "Press [Enter] to continue after Xcode Command Line Tools are confirmed as installed, or Ctrl+C to exit and re-run later."
            if ! xcode-select -p &> /dev/null; then
                log_error "❌ Xcode Command Line Tools still not found after attempting installation."
                log_error "   Please ensure they are fully installed (sometimes requires opening Xcode once) and re-run the script."
                exit 1
            fi
            log_success "✅ Xcode Command Line Tools installation detected."
        else
            log_success "✅ Xcode Command Line Tools already installed"
        fi

        log_info ""
        log_info "💡 For optimal performance and to avoid issues, please also consider the following manual steps:"
        log_info "   1. Exclude your Chromium/HenSurf checkout directory from Spotlight indexing."
        log_info "      (System Settings -> Siri & Spotlight -> Spotlight Privacy... -> Add your checkout folder)"
        log_info "   2. Ensure the Xcode license agreement is accepted by running in your terminal:"
        log_info "      sudo xcodebuild -license accept"
        # No log_info for the read prompt itself, as it's interactive.
        read -r -p "Press [Enter] to acknowledge these recommendations and continue..."
        echo # Add a newline after the user presses Enter for better formatting
        ;;

    "windows")
        log_info "💻 Detected Windows"

        # Git (assumed if running in Git Bash, but good to mention)
        log_info "🌐 Checking for Git..."
        if ! command_exists "git"; then
            log_error "❌ Git not found. Please install Git for Windows."
            log_error "   Visit https://git-scm.com/download/win"
            log_error "   This script requires Git to be in PATH, especially for depot_tools."
            exit 1
        else
            log_success "✅ Git found."
        fi

        # Ninja
        log_info "🥷 Checking for Ninja..."
        if ! command_exists "ninja"; then
            NINJA_VERSION="1.11.1"
            NINJA_URL="https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-win.zip"

            log_info "ℹ️ Ninja not found by command_exists \"ninja\"."
            TOOLS_DIR="$PROJECT_ROOT/tools"
            NINJA_DIR="$TOOLS_DIR/ninja"
            NINJA_EXE_PATH="$NINJA_DIR/ninja.exe"

            # Check if we previously downloaded it
            if [ -f "$NINJA_EXE_PATH" ]; then
                log_info "✅ Ninja found in $NINJA_DIR. Adding to PATH."
                export PATH="$NINJA_DIR:$PATH" # Keep local Ninja PATH addition for now
                if command_exists "ninja"; then
                    log_success "✅ Ninja configured successfully from $NINJA_DIR."
                else
                    log_error "❌ Failed to configure Ninja from $NINJA_DIR even though ninja.exe exists. Manual check needed."
                fi
            else
                log_warn "🤔 Ninja not found in $NINJA_EXE_PATH. Attempting to download..."
                if ! command_exists "curl" || ! command_exists "unzip"; then
                    log_error "❌ curl and/or unzip are not installed. Cannot download Ninja automatically."
                    log_error "   Please install curl and unzip, then re-run this script,"
                    log_error "   or install Ninja manually:"
                    log_error "   Using Chocolatey: choco install ninja"
                    log_error "   Or download from https://github.com/ninja-build/ninja/releases and add to PATH."
                    log_info "   Continuing, but build may fail if Ninja is not made available."
                else
                    log_info "📦 Attempting to download Ninja v${NINJA_VERSION}..."
                    mkdir -p "$NINJA_DIR"
                    if curl -L "$NINJA_URL" -o "$NINJA_DIR/ninja-win.zip"; then
                        log_success "✅ Downloaded ninja-win.zip."
                        if unzip -oq "$NINJA_DIR/ninja-win.zip" ninja.exe -d "$NINJA_DIR"; then
                            log_success "✅ Unzipped ninja.exe to $NINJA_DIR."
                            export PATH="$NINJA_DIR:$PATH" # Keep local Ninja PATH addition
                            if command_exists "ninja"; then
                                log_success "✅ Ninja v${NINJA_VERSION} downloaded and configured successfully."
                            else
                                log_error "❌ Failed to configure Ninja after download. Check PATH and $NINJA_EXE_PATH."
                            fi
                            log_info "🧹 Cleaning up downloaded zip file..."
                            rm "$NINJA_DIR/ninja-win.zip"
                        else
                            log_error "❌ Failed to unzip ninja-win.zip."
                            log_error "   Please install Ninja manually or check your unzip utility."
                            rm "$NINJA_DIR/ninja-win.zip" # Clean up failed download
                        fi
                    else
                        log_error "❌ Failed to download Ninja from $NINJA_URL."
                        log_error "   Please install Ninja manually."
                    fi
                fi
            fi
        else
            log_success "✅ Ninja found."
        fi

        # Visual Studio Build Tools
        log_info "🔧 Visual Studio Build Tools:"
        log_info "   Please ensure you have Visual Studio C++ Build Tools installed."
        log_info "   Required: 'Desktop development with C++' workload."
        log_info "   Recommended: Visual Studio 2019 (e.g., v16.11.14+) or Visual Studio 2022."
        log_info "   Chromium's gclient hooks may attempt to manage this if specific environment variables are set (e.g., DEPOT_TOOLS_WIN_TOOLCHAIN=0)."
        log_info "   If you have issues, ensure VS is correctly installed and discoverable by depot_tools."
        read -r -p "Press [Enter] to acknowledge and continue..."
        echo # Add a newline after the user presses Enter

        log_info ""
        log_info "💡 Build Caching on Windows:"
        log_info "   For improved build times, consider using Mozilla's 'sccache' (https://github.com/mozilla/sccache)."
        log_info "   It can replace cl.exe and cache compilation results, similar to ccache on Linux/macOS."
        log_info "   Alternatively, investigate build caching features within Visual Studio itself."
        log_info "   Note: The ccache configurations in build.sh are primarily for Linux/macOS environments."
        log_info "" # Ensure a blank line for readability before next section.
        ;;

    "linux")
        log_info "🐧 Detected Linux"
        if command_exists "apt-get"; then
            log_info "Distro: Debian/Ubuntu (apt package manager found)"
            log_info "📦 Installing dependencies for Debian/Ubuntu..."
            sudo apt-get update
            if ! sudo apt-get install -y python3 git ninja-build pkg-config build-essential libgtk-3-dev libnss3-dev libasound2-dev libcups2-dev libxtst-dev libxss1 libatk1.0-dev libatk-bridge2.0-dev libdrm-dev libgbm-dev libx11-xcb-dev uuid-dev ccache; then
                log_error "Failed to install dependencies via apt-get. Please check the output."
                exit 1
            fi
            log_success "✅ Successfully installed Debian/Ubuntu dependencies."
        elif command_exists "dnf"; then
            log_info "Distro: Fedora (dnf package manager found)"
            log_info "📦 Installing dependencies for Fedora..."
            if ! sudo dnf install -y python3 git ninja-build pkgconf-pkg-config gcc-c++ gtk3-devel nss-devel alsa-lib-devel cups-devel libXtst-devel libXScrnSaver-devel atk-devel at-spi2-atk-devel libdrm-devel libgbm-devel libX11-xcb-devel libuuid-devel ccache; then
                log_error "Failed to install dependencies via dnf. Please check the output."
                exit 1
            fi
            log_success "✅ Successfully installed Fedora dependencies."
        elif command_exists "pacman"; then
            log_info "Distro: Arch Linux (pacman package manager found)"
            log_info "📦 Installing dependencies for Arch Linux..."
            if ! sudo pacman -Syu --noconfirm --needed base-devel python git ninja pkgconf gtk3 nss alsa-lib cups libxtst libxscrnsaver libatk at-spi2-atk libdrm libgbm libx11 libxcb util-linux ccache; then
                log_error "Failed to install dependencies via pacman. Please check the output."
                exit 1
            fi
            log_success "✅ Successfully installed Arch Linux dependencies."
        else
            log_error "❌ Unsupported Linux distribution or package manager not found (apt-get, dnf, pacman)."
            log_info "Please install the following dependencies manually:"
            log_info "  python3, git, ninja-build (or ninja), pkg-config, gcc/g++ (build-essential),"
            log_info "  libgtk-3-dev, libnss3-dev, libasound2-dev, libcups2-dev, libxtst-dev,"
            log_info "  libxss1 (or libxscrnsaver), libatk1.0-dev, libatk-bridge2.0-dev, libdrm-dev, libgbm-dev,"
            log_info "  libx11-xcb-dev, uuid-dev (or libuuid-devel or util-linux for uuidgen)"
            exit 1
        fi
        ;;
    *)
        log_error "Unsupported operating system: $OSTYPE (resolved to $OS_TYPE by get_os_type)"
        exit 1
        ;;
esac

# Check Python version (common logic for macOS, Linux, and Windows)
log_info "🐍 Checking Python version (requires 3.8+)..."
if ! check_python_version "3" "8"; then
    # The check_python_version function already logs detailed errors.
    # Add any OS-specific advice for installing Python if desired.
    if [[ "$OS_TYPE" == "macos" ]]; then
        log_info "   On macOS, you can install Python using: brew install python"
    elif [[ "$OS_TYPE" == "linux" ]]; then
        # Add distro-specific advice if possible, or general advice
        log_info "   On Linux, use your system's package manager, e.g., sudo apt-get install python3 (Debian/Ubuntu) or sudo dnf install python3 (Fedora)."
    elif [[ "$OS_TYPE" == "windows" ]]; then
        log_info "   On Windows, download from https://www.python.org/downloads/windows/ or use Chocolatey: choco install python."
    fi
    exit 1
fi

# Depot Tools setup
DEPOT_TOOLS_DIR=$(get_depot_tools_dir "$PROJECT_ROOT")
if [ -z "$DEPOT_TOOLS_DIR" ]; then
    log_error "Failed to determine depot_tools directory path. Exiting."
    exit 1
fi

# Check if depot_tools exists, if not, clone it
if [ ! -d "$DEPOT_TOOLS_DIR" ]; then
    log_info "📦 depot_tools not found at '$DEPOT_TOOLS_DIR'. Attempting to clone..."
    PARENT_OF_DEPOT_TOOLS=$(dirname "$DEPOT_TOOLS_DIR")
    mkdir -p "$PARENT_OF_DEPOT_TOOLS" # Ensure parent directory exists

    # Check for Git before attempting to clone
    if ! command_exists "git"; then
        log_error "❌ Git command not found, cannot clone depot_tools. Please install Git and re-run."
        exit 1
    fi

    ORIGINAL_PWD=$(pwd)
    log_info "   Attempting to clone depot_tools into '$PARENT_OF_DEPOT_TOOLS'..."
    # Using safe_cd for directory changes
    if safe_cd "$PARENT_OF_DEPOT_TOOLS"; then
        if git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git; then
            log_success "✅ Successfully cloned depot_tools into '$DEPOT_TOOLS_DIR'."
        else
            log_error "❌ Failed to clone depot_tools. Please check your internet connection and Git setup."
            safe_cd "$ORIGINAL_PWD" # Go back to original dir before exiting
            exit 1
        fi
        safe_cd "$ORIGINAL_PWD" # Return to the original directory
    else
        # safe_cd would have already logged an error.
        log_error "❌ Could not change to directory '$PARENT_OF_DEPOT_TOOLS' to clone depot_tools. Please check permissions and path."
        exit 1
    fi
else
    log_success "✅ depot_tools already exists at '$DEPOT_TOOLS_DIR'."
fi

# Add depot_tools to PATH
if ! add_depot_tools_to_path "$DEPOT_TOOLS_DIR"; then
    # Error message is already logged by add_depot_tools_to_path
    # It also checks for gn and autoninja availability.
    exit 1
fi

if [[ "$OS_TYPE" == "windows" ]]; then
    log_info "   (Note: This PATH change is only for the current Git Bash/MSYS session.)"
    log_success "✅ All core dependencies checked for Windows!"
    log_info "   (Note: The PATH change for depot_tools is only for the current Git Bash/MSYS session.)"
else
    log_success "✅ All core dependencies installed/checked and depot_tools configured for this session!"
    log_info "   (Note: The PATH change for depot_tools is only for the current terminal session.)"
fi

log_info ""
log_info "--- Next Steps ---"
if [[ "$OS_TYPE" == "windows" ]]; then
    log_info "1. IMPORTANT: Add depot_tools to your Windows System PATH environment variable permanently if you haven't already."
    log_info "   You can do this through 'System Properties' > 'Environment Variables', or by using 'setx PATH \"%PATH%;C:\\path\\to\\depot_tools\"' in cmd.exe (run as admin for system-wide effect)."
    log_info "   Replace 'C:\\path\\to\\depot_tools' with the actual absolute path: $DEPOT_TOOLS_DIR"
    log_info "   Restart your Git Bash/MSYS terminal and Command Prompt/PowerShell after making permanent changes for them to take effect."
else
    log_info "1. IMPORTANT: Add depot_tools to your shell's startup file (e.g., ~/.bashrc, ~/.zshrc, ~/.profile) if you haven't already:"
    log_info "   Example command: echo 'export PATH=\"$DEPOT_TOOLS_DIR:\$PATH\"' >> ~/.your_shell_rc_file"
    log_info "   Replace '.your_shell_rc_file' with the actual file for your shell (e.g., ~/.bashrc)."
    log_info "   Then, source the file (e.g., 'source ~/.bashrc') or open a new terminal."
fi
log_info "2. Run './scripts/fetch-chromium.sh' to download Chromium source (it will use depot_tools from the PATH)."
log_info "3. Run './scripts/apply-patches.sh' to apply HenSurf customizations."
log_info "4. Run './scripts/build.sh' to build HenSurf."
log_info ""
log_warn "⚠️ Note: The full Chromium build process requires significant disk space (~100GB) and can take several hours."