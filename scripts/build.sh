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

# Determine script and project paths
SCRIPT_DIR_BUILD=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT_BUILD=$(cd "$SCRIPT_DIR_BUILD/.." &>/dev/null && pwd)

# Corrected depot_tools path logic:
# Assuming depot_tools is ALONGSIDE HenSurf project directory (e.g. ../depot_tools)
DEPOT_TOOLS_DIR_ABS=$(cd "$PROJECT_ROOT_BUILD/../depot_tools" &>/dev/null && pwd)

if [ ! -d "$DEPOT_TOOLS_DIR_ABS" ]; then
    echo "❌ depot_tools not found at expected absolute location: $PROJECT_ROOT_BUILD/../depot_tools"
    echo "   This path was derived from this script's location: $SCRIPT_DIR_BUILD"
    echo "   Please ensure depot_tools is cloned adjacent to the HenSurf project directory."
    exit 1
fi
export PATH="$DEPOT_TOOLS_DIR_ABS:$PATH"
echo "🔧 Added depot_tools to PATH: $DEPOT_TOOLS_DIR_ABS"

# Navigate to the chromium source directory
CHROMIUM_SRC_DIR="$PROJECT_ROOT_BUILD/chromium/src"
if [ ! -d "$CHROMIUM_SRC_DIR" ]; then
    echo "❌ Chromium source directory not found at $CHROMIUM_SRC_DIR"
    echo "   Please ensure you have run ./scripts/fetch-chromium.sh successfully."
    exit 1
fi
cd "$CHROMIUM_SRC_DIR"
echo "Current directory: $(pwd)"


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
    else # Fallback for systems without /proc/meminfo but might have 'free'
        MEMORY_KB=$(free | grep Mem: | awk '{print $2}')
        if [[ "$MEMORY_KB" =~ ^[0-9]+$ ]]; then
            MEMORY_GB=$(awk -v memkb="$MEMORY_KB" 'BEGIN { printf "%.0f", memkb / 1024 / 1024 }')
        else
            echo "⚠️ Could not determine system memory from /proc/meminfo or free."
        fi
    fi
    if command -v nproc &> /dev/null; then
        CPU_CORES=$(nproc)
    else
        CPU_CORES=$(grep -c ^processor /proc/cpuinfo || echo 1) # Fallback for CPU cores
        echo "⚠️ nproc command not found, using /proc/cpuinfo or defaulting to $CPU_CORES CPU core(s) for estimates."
    fi
    echo "   Detected RAM: ${MEMORY_GB}GB, CPU Cores: $CPU_CORES"
elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    echo "💻 Checking Windows system requirements..."
    if ! command -v wmic &> /dev/null; then
        echo "⚠️ 'wmic' command not found. Cannot check system requirements accurately."
        MEMORY_GB=0 # Explicitly set to 0 if wmic not found
        CPU_CORES=1 # Default
    else
        TOTAL_MEM_KB_STR=$(wmic OS get TotalVisibleMemorySize /value | tr -d '\r' | grep TotalVisibleMemorySize | cut -d'=' -f2)
        if [[ -n "$TOTAL_MEM_KB_STR" && "$TOTAL_MEM_KB_STR" =~ ^[0-9]+$ ]]; then
            MEMORY_GB=$(awk -v memkb="$TOTAL_MEM_KB_STR" 'BEGIN { printf "%.0f", memkb / 1024 / 1024 }')
        else
            echo "⚠️ Could not determine TotalVisibleMemorySize using wmic. Output: '$TOTAL_MEM_KB_STR'"
            MEMORY_GB=0
        fi

        CPU_CORES_STR=$(wmic cpu get NumberOfLogicalProcessors /value | tr -d '\r' | grep NumberOfLogicalProcessors | cut -d'=' -f2)
        if [[ -n "$CPU_CORES_STR" && "$CPU_CORES_STR" =~ ^[0-9]+$ ]]; then
            CPU_CORES=$CPU_CORES_STR
        else
            echo "⚠️ Could not determine NumberOfLogicalProcessors using wmic. Output: '$CPU_CORES_STR'"
            CPU_CORES=1 # Default if detection fails
        fi
    fi
    echo "   Detected RAM: ${MEMORY_GB}GB, CPU Cores: $CPU_CORES"
else
    echo "⚠️ Unsupported OS ($OSTYPE) for detailed system checks. Proceeding with default assumptions (0GB RAM, 1 CPU core)."
    MEMORY_GB=0 # Ensure it's 0 if OS is unsupported
    CPU_CORES=1
fi

MIN_RAM_GB=16
if [ "$MEMORY_GB" -lt "$MIN_RAM_GB" ]; then
    if [ "$MEMORY_GB" -gt 0 ]; then # Only warn if we got a valid reading and it's below threshold
        echo "⚠️  Warning: Only ${MEMORY_GB}GB RAM detected. ${MIN_RAM_GB}GB+ recommended for building Chromium."
    elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]] || [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
         # If OS is known but RAM is 0, it means detection failed.
        echo "⚠️  Warning: Could not reliably determine system RAM. ${MIN_RAM_GB}GB+ recommended for building Chromium."
    fi
    # For unknown OS, the warning about unsupported OS for checks has already been printed.
    # Only prompt if we are on a known OS or if RAM detection gave a value (even if 0 due to error).
    if [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]] || \
       [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]] || [ "$MEMORY_GB" -gt 0 ]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Check available disk space
MIN_BUILD_DISK_SPACE_GB=50
AVAILABLE_SPACE_GB=0 # Default to 0

if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    AVAILABLE_SPACE_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//' | tr -d '[:space:]')
    echo "Disk space check (Linux/macOS): ${AVAILABLE_SPACE_GB}GB available in $(pwd)."
elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    echo "💻 Checking disk space on Windows in $(pwd)..."
    CURRENT_DRIVE_LETTER_BUILD=$(pwd -W | cut -d':' -f1)
    if ! command -v wmic &> /dev/null; then
        echo "⚠️ 'wmic' command not found. Cannot check disk space accurately on Windows."
        AVAILABLE_SPACE_GB=0
    else
        AVAILABLE_BYTES_STR_BUILD=$(wmic logicaldisk where "DeviceID='${CURRENT_DRIVE_LETTER_BUILD}:'" get FreeSpace /value | tr -d '\r' | grep FreeSpace | cut -d'=' -f2)
        if [[ -z "$AVAILABLE_BYTES_STR_BUILD" || ! "$AVAILABLE_BYTES_STR_BUILD" =~ ^[0-9]+$ ]]; then
             echo "⚠️ Could not determine free space using wmic for drive ${CURRENT_DRIVE_LETTER_BUILD}: (Output: '$AVAILABLE_BYTES_STR_BUILD')."
             AVAILABLE_SPACE_GB=0
        else
            AVAILABLE_SPACE_GB=$(awk -v bytes="$AVAILABLE_BYTES_STR_BUILD" 'BEGIN { printf "%.0f", bytes / 1024 / 1024 / 1024 }')
        fi
    fi
    echo "Drive ${CURRENT_DRIVE_LETTER_BUILD}: has approximately ${AVAILABLE_SPACE_GB}GB free."
else
    echo "⚠️ Unsupported OS for disk space check: $OSTYPE. Assuming ${MIN_BUILD_DISK_SPACE_GB}GB available."
    AVAILABLE_SPACE_GB=${MIN_BUILD_DISK_SPACE_GB}
fi

# Ensure AVAILABLE_SPACE_GB is a number, default to 0 if not
if ! [[ "$AVAILABLE_SPACE_GB" =~ ^[0-9]+$ ]]; then
    echo "⚠️ Could not reliably determine available disk space in $(pwd). Detected: '$AVAILABLE_SPACE_GB'."
    AVAILABLE_SPACE_GB=0
fi

if [ "$AVAILABLE_SPACE_GB" -lt "$MIN_BUILD_DISK_SPACE_GB" ]; then
    echo "⚠️  Warning: Only ${AVAILABLE_SPACE_GB}GB detected as available in $(pwd). Build output requires ~${MIN_BUILD_DISK_SPACE_GB}GB."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Determine target_cpu for macOS
GN_ARGS_EXTRA=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    HOST_ARCH=$(uname -m)
    if [[ "$HOST_ARCH" == "arm64" ]]; then
        echo "🍏 Detected Apple Silicon (arm64). Setting target_cpu=arm64."
        GN_ARGS_EXTRA="--args=target_cpu=\"arm64\""
    elif [[ "$HOST_ARCH" == "x86_64" ]]; then
        echo "🍏 Detected Intel (x86_64). Setting target_cpu=x64."
        GN_ARGS_EXTRA="--args=target_cpu=\"x64\""
    else
        echo "⚠️ Unknown macOS architecture: $HOST_ARCH. Using default target_cpu from args.gn."
    fi
fi

# Generate build files
echo "⚙️  Generating build files..."
if [[ -n "$GN_ARGS_EXTRA" ]]; then
    # Use eval to correctly parse the quoted arguments within GN_ARGS_EXTRA
    eval "gn gen out/HenSurf $GN_ARGS_EXTRA"
else
    gn gen out/HenSurf
fi

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

    # App Name Discovery (is_chrome_branded = false, so expect "Chromium.app")
    EXPECTED_CHROMIUM_APP_NAME="Chromium.app"
    APP_COPIED=false
    if [ -d "out/HenSurf/${EXPECTED_CHROMIUM_APP_NAME}" ]; then
        echo "Found ${EXPECTED_CHROMIUM_APP_NAME}, copying to HenSurf.app..."
        cp -R "out/HenSurf/${EXPECTED_CHROMIUM_APP_NAME}" "out/HenSurf/HenSurf.app"
        APP_COPIED=true
    fi

    if [ "$APP_COPIED" = true ] && [ -d "out/HenSurf/HenSurf.app" ]; then
        # Update Info.plist
        PLIST_BUDDY="/usr/libexec/PlistBuddy"
        INFO_PLIST="out/HenSurf/HenSurf.app/Contents/Info.plist"
        TARGET_MACOS_VERSION="10.15" # From hensurf.gn's mac_deployment_target
        HENSURF_VERSION="1.0.0" # Placeholder, ideally from a version file
        HENSURF_BUILD_NUMBER="1" # Placeholder for build number

        if [ -f "$PLIST_BUDDY" ] && [ -f "$INFO_PLIST" ]; then
            echo "Updating Info.plist at: $INFO_PLIST"
            # Set Bundle Name (typically app name without .app)
            "$PLIST_BUDDY" -c "Set :CFBundleName HenSurf" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleName"
            # Set Display Name (shown in Finder)
            "$PLIST_BUDDY" -c "Set :CFBundleDisplayName HenSurf Browser" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleDisplayName"
            # Set Bundle Identifier (unique ID)
            "$PLIST_BUDDY" -c "Set :CFBundleIdentifier com.hensurf.browser" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleIdentifier"
            # Set Short Version String (marketing version)
            "$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $HENSURF_VERSION" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleShortVersionString"
            # Set Bundle Version (build number)
            "$PLIST_BUDDY" -c "Set :CFBundleVersion $HENSURF_BUILD_NUMBER" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleVersion"
            # Set Minimum System Version
            "$PLIST_BUDDY" -c "Set :LSMinimumSystemVersion $TARGET_MACOS_VERSION" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set LSMinimumSystemVersion"
            # Set Icon File
            "$PLIST_BUDDY" -c "Set :CFBundleIconFile app.icns" "$INFO_PLIST" 2>/dev/null || echo "Warning: Failed to set CFBundleIconFile"
            # CFBundleExecutable should already be set correctly to 'Chromium' from the source app.
            echo "✅ HenSurf.app bundle created and Info.plist configured successfully!"
        else
            echo "⚠️  PlistBuddy tool ($PLIST_BUDDY) or Info.plist ($INFO_PLIST) not found. Cannot customize app bundle."
            echo "   Expected Info.plist at: out/HenSurf/HenSurf.app/Contents/Info.plist"
        fi
    else
        echo "⚠️  Could not find the expected base app bundle '${EXPECTED_CHROMIUM_APP_NAME}' in out/HenSurf/ to create HenSurf.app."
        echo "   The raw 'chrome' binary should still be available."
    fi

    # Build macOS installer (optional)
    echo "📦 Building macOS installer (dmg)..."
    autoninja -C out/HenSurf mini_installer 2>&1 | tee -a out/HenSurf/build.log || echo "ℹ️  macOS installer build step finished (may have warnings or be skipped if not configured)."

elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    echo "📦 Building Windows installer (mini_installer)..."
    autoninja -C out/HenSurf mini_installer 2>&1 | tee -a out/HenSurf/build.log || echo "ℹ️  Windows installer build step finished (may have warnings or be skipped if not configured)."
    # Check for common installer names
    if [ -f "out/HenSurf/mini_installer.exe" ]; then
        echo "✅ Windows mini_installer.exe found."
    elif [ -f "out/HenSurf/setup.exe" ]; then
        echo "✅ Windows setup.exe found."
    else
        echo "⚠️  Windows installer (mini_installer.exe or setup.exe) not found in out/HenSurf/. Build might have skipped it or an issue occurred."
    fi
fi # End of OS specific bundling

echo ""
echo "🎉 HenSurf build completed successfully!"
echo ""
echo "📍 Build artifacts location (relative to $CHROMIUM_SRC_DIR):"
echo "   Main executable: out/HenSurf/chrome${EXE_SUFFIX}" # EXE_SUFFIX will be .exe on windows, empty otherwise
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "out/HenSurf/HenSurf.app" ]; then
        echo "   macOS App Bundle: out/HenSurf/HenSurf.app"
    fi
    # Attempt to find the actual DMG name as mini_installer might produce versioned names
    DMG_FILE=$(ls out/HenSurf/*.dmg 2>/dev/null | head -n 1)
    if [ -f "$DMG_FILE" ]; then
        echo "   macOS Installer:  $(basename "$DMG_FILE") (in out/HenSurf/)"
    elif [ -f "out/HenSurf/HenSurf.dmg" ]; then # Fallback to generic name
         echo "   macOS Installer:  HenSurf.dmg (in out/HenSurf/)"
    fi
elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    if [ -f "out/HenSurf/mini_installer.exe" ]; then
        echo "   Windows Installer: out/HenSurf/mini_installer.exe"
    elif [ -f "out/HenSurf/setup.exe" ]; then # Common alternative name
        echo "   Windows Installer: out/HenSurf/setup.exe"
    else
        # Check for versioned installer name like chrome_installer.exe, etc.
        WIN_INSTALLER_FILE=$(ls out/HenSurf/*installer.exe 2>/dev/null | head -n 1)
        if [ -f "$WIN_INSTALLER_FILE" ]; then
             echo "   Windows Installer: $(basename "$WIN_INSTALLER_FILE") (in out/HenSurf/)"
        fi
    fi
fi
echo "   Build log: out/HenSurf/build.log"
echo ""
echo "🚀 To run HenSurf (from $CHROMIUM_SRC_DIR directory):"

# Define EXE_SUFFIX for Windows
EXE_SUFFIX=""
if [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    EXE_SUFFIX=".exe"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "out/HenSurf/HenSurf.app" ]; then
        echo "   open out/HenSurf/HenSurf.app"
    else
        echo "   ./out/HenSurf/chrome  (App bundle creation failed or was skipped)"
    fi
elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    echo "   ./out/HenSurf/chrome${EXE_SUFFIX}"
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