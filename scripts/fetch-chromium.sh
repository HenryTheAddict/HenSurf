#!/bin/bash

# HenSurf Browser - Chromium Source Fetch Script
# This script downloads the Chromium source code

set -e

echo "🌐 Fetching Chromium source code for HenSurf..."

# Determine script and project paths
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)

# depot_tools path logic:
# 1. Check DEPOT_TOOLS_PATH environment variable
# 2. Fallback to common locations ($PROJECT_ROOT/../depot_tools or $PROJECT_ROOT/depot_tools)

DEPOT_TOOLS_DIR=""
if [ -n "$DEPOT_TOOLS_PATH" ] && [ -d "$DEPOT_TOOLS_PATH" ]; then
    DEPOT_TOOLS_DIR=$(cd "$DEPOT_TOOLS_PATH" &>/dev/null && pwd) # Get absolute path
    echo "ℹ️ Using depot_tools from DEPOT_TOOLS_PATH environment variable: $DEPOT_TOOLS_DIR"
else
    # Try to find depot_tools, assuming it's adjacent to the project root
    DEPOT_TOOLS_DIR_GUESS_1="$PROJECT_ROOT/../depot_tools"
    # Fallback if it's inside the project root
    DEPOT_TOOLS_DIR_GUESS_2="$PROJECT_ROOT/depot_tools"

    if [ -d "$DEPOT_TOOLS_DIR_GUESS_1" ]; then
        DEPOT_TOOLS_DIR=$(cd "$DEPOT_TOOLS_DIR_GUESS_1" &>/dev/null && pwd)
        echo "ℹ️ Using depot_tools from default location (adjacent to project): $DEPOT_TOOLS_DIR"
    elif [ -d "$DEPOT_TOOLS_DIR_GUESS_2" ]; then
        DEPOT_TOOLS_DIR=$(cd "$DEPOT_TOOLS_DIR_GUESS_2" &>/dev/null && pwd)
        echo "ℹ️ Using depot_tools from fallback location (inside project): $DEPOT_TOOLS_DIR"
    else
        echo "❌ depot_tools not found."
        echo "   Checked DEPOT_TOOLS_PATH environment variable (was not set or invalid)."
        echo "   Checked default location: $DEPOT_TOOLS_DIR_GUESS_1"
        echo "   Checked fallback location: $DEPOT_TOOLS_DIR_GUESS_2"
        echo "   Please ensure depot_tools is correctly installed and accessible,"
        echo "   or set the DEPOT_TOOLS_PATH environment variable to its location."
        echo "   Consider running ./scripts/install-deps.sh first if depot_tools is not yet installed."
        exit 1
    fi
fi

export PATH="$DEPOT_TOOLS_DIR:$PATH"
echo "🔧 Added depot_tools to PATH for this session."

# Check available disk space
MIN_DISK_SPACE_GB=100
AVAILABLE_SPACE_GB=0

if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Attempt to get free space in GB directly. -B G ensures output is in GB.
    # The awk command extracts the 4th field (Available) from the 2nd line.
    # sed removes the 'G' suffix.
    AVAILABLE_SPACE_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//' | tr -d '[:space:]')
    echo "Disk space check (Linux/macOS): ${AVAILABLE_SPACE_GB}GB available."
elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    echo "💻 Checking disk space on Windows..."
    CURRENT_DRIVE_LETTER=$(pwd -W | cut -d':' -f1)
    if ! command -v wmic &> /dev/null; then
        echo "⚠️ 'wmic' command not found. Cannot check disk space accurately on Windows."
        echo "   Please ensure at least ${MIN_DISK_SPACE_GB}GB is available on drive ${CURRENT_DRIVE_LETTER}:"
        # Set to a value that allows proceeding but shows warning or prompts user.
        # Or, conservatively, set to 0 to always trigger manual confirmation if wmic fails.
        AVAILABLE_SPACE_GB=0
    else
        # wmic output can have trailing carriage returns or extra spaces.
        # tr -d '\r' removes carriage returns.
        # grep FreeSpace ensures we only get that line.
        # cut -d'=' -f2 gets the value after '='.
        AVAILABLE_BYTES_STR=$(wmic logicaldisk where "DeviceID='${CURRENT_DRIVE_LETTER}:'" get FreeSpace /value | tr -d '\r' | grep FreeSpace | cut -d'=' -f2)
        if [[ -z "$AVAILABLE_BYTES_STR" || ! "$AVAILABLE_BYTES_STR" =~ ^[0-9]+$ ]]; then
             echo "⚠️ Could not determine free space using wmic for drive ${CURRENT_DRIVE_LETTER}: (Output: '$AVAILABLE_BYTES_STR')."
             AVAILABLE_SPACE_GB=0 # Assume not enough if value is weird
        else
            # Using awk for floating point division as bc might not be available by default in Git Bash
            # awk can handle large numbers. Result is rounded to nearest integer.
            AVAILABLE_SPACE_GB=$(awk -v bytes="$AVAILABLE_BYTES_STR" 'BEGIN { printf "%.0f", bytes / 1024 / 1024 / 1024 }')
        fi
    fi
    echo "Drive ${CURRENT_DRIVE_LETTER}: has approximately ${AVAILABLE_SPACE_GB}GB free."
else
    echo "⚠️ Unsupported OS for disk space check: $OSTYPE. Assuming ${MIN_DISK_SPACE_GB}GB available."
    AVAILABLE_SPACE_GB=${MIN_DISK_SPACE_GB} # Assume enough to proceed, but user should be aware
fi

# Ensure AVAILABLE_SPACE_GB is a number, default to 0 if not (e.g. df output was weird)
if ! [[ "$AVAILABLE_SPACE_GB" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Could not reliably determine available disk space. Detected: '$AVAILABLE_SPACE_GB'."
    AVAILABLE_SPACE_GB=0
fi

if [ "$AVAILABLE_SPACE_GB" -lt "$MIN_DISK_SPACE_GB" ]; then
    echo "⚠️  Warning: Only ${AVAILABLE_SPACE_GB}GB detected as available. Chromium source requires at least ${MIN_DISK_SPACE_GB}GB."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Define HenSurf root and Chromium directory path (relative to HenSurf root)
HENSURF_ROOT_DIR="$PROJECT_ROOT"
CHROMIUM_DIR="$HENSURF_ROOT_DIR/chromium"

# Create chromium directory if it doesn't exist
if [ ! -d "$CHROMIUM_DIR" ]; then
    echo "📁 Creating chromium directory at $CHROMIUM_DIR..."
    mkdir -p "$CHROMIUM_DIR" # Use -p to create parent dirs if needed, though unlikely here
fi

cd "$CHROMIUM_DIR"
echo "Current directory: $(pwd)"

# Check if .gclient exists (indicates previous fetch)
if [ -f ".gclient" ]; then
    echo "🔄 Updating existing Chromium source..."
    gclient sync
else
    echo "📦 Fetching Chromium source into $(pwd) (this will take a while)..."
    echo "⏳ Expected time: 30-60 minutes or more depending on internet speed and machine specs."
    
    # Fetch Chromium source. This command creates the 'src' directory inside the current directory.
    # The .gclient file is also created in the current directory.
    fetch --nohooks chromium
    
    echo "🔧 Running gclient hooks in $(pwd)..."
    # gclient runhooks should be run in the directory that contains the 'src' directory
    # and the .gclient file. This is the current directory ($CHROMIUM_DIR).
    if [ ! -f ".gclient" ]; then
        echo "❌ .gclient file not found in $(pwd) after fetch. This is unexpected."
        echo "   Ensure 'fetch --nohooks chromium' completed successfully."
        exit 1
    fi
    if [ ! -d "src" ]; then
        echo "❌ 'src' directory not found in $(pwd) after fetch. This is unexpected."
        exit 1
    fi
    gclient runhooks
fi

echo "✅ Chromium source code ready in $(pwd)/src!"
echo ""
echo "Next steps:"
echo "1. Run $HENSURF_ROOT_DIR/scripts/apply-patches.sh to apply HenSurf customizations"
echo "2. Run $HENSURF_ROOT_DIR/scripts/build.sh to build HenSurf"