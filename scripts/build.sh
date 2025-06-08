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

# depot_tools path logic:
# 1. Check DEPOT_TOOLS_PATH environment variable
# 2. Fallback to assuming depot_tools is ALONGSIDE HenSurf project directory

if [ -n "$DEPOT_TOOLS_PATH" ] && [ -d "$DEPOT_TOOLS_PATH" ]; then
    DEPOT_TOOLS_DIR_ABS=$(cd "$DEPOT_TOOLS_PATH" &>/dev/null && pwd)
    echo "ℹ️ Using depot_tools from DEPOT_TOOLS_PATH environment variable: $DEPOT_TOOLS_DIR_ABS"
else
    DEPOT_TOOLS_DIR_ABS=$(cd "$PROJECT_ROOT_BUILD/../depot_tools" &>/dev/null && pwd)
    if [ ! -d "$DEPOT_TOOLS_DIR_ABS" ]; then
        echo "❌ depot_tools not found at $PROJECT_ROOT_BUILD/../depot_tools (derived from script location)."
        echo "   Please ensure depot_tools is cloned adjacent to the HenSurf project directory,"
        echo "   or set the DEPOT_TOOLS_PATH environment variable to its location."
        exit 1
    fi
    echo "ℹ️ Using depot_tools from default location: $DEPOT_TOOLS_DIR_ABS"
fi

export PATH="$DEPOT_TOOLS_DIR_ABS:$PATH"
echo "🔧 Added depot_tools to PATH."

# Early checks for gn and autoninja
if ! command -v gn &> /dev/null; then
    echo "❌ 'gn' command not found after setting depot_tools path."
    echo "   Please ensure depot_tools is correctly installed and configured."
    echo "   Checked PATH includes: $DEPOT_TOOLS_DIR_ABS"
    exit 1
else
    echo "✅ 'gn' command found: $(command -v gn)"
    gn --version
fi

if ! command -v autoninja &> /dev/null; then
    echo "❌ 'autoninja' command not found after setting depot_tools path."
    echo "   Please ensure depot_tools is correctly installed and configured."
    echo "   Checked PATH includes: $DEPOT_TOOLS_DIR_ABS"
    exit 1
else
    echo "✅ 'autoninja' command found: $(command -v autoninja)"
    autoninja --version
fi

# Configure ccache
export CCACHE_CPP2=true
export CCACHE_SLOPPINESS="time_macros"
# Optional: export CCACHE_DIR="/path/to/your/ccache_directory"

# Verify ccache is found and print stats (optional, but good for debugging)
if command -v ccache &> /dev/null; then
    echo "✅ ccache found: $(command -v ccache)"
    echo "Initial ccache statistics:"
    ccache -s
else
    echo "⚠️ ccache command not found. Build will proceed without ccache (ensure use_ccache is false in args.gn or ccache is installed)."
fi

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
GN_ARGS_EXTRA_OS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    HOST_ARCH=$(uname -m)
    if [[ "$HOST_ARCH" == "arm64" ]]; then
        echo "🍏 Detected Apple Silicon (arm64). Setting target_cpu=arm64."
        GN_ARGS_EXTRA_OS="target_cpu=\"arm64\""
    elif [[ "$HOST_ARCH" == "x86_64" ]]; then
        echo "🍏 Detected Intel (x86_64). Setting target_cpu=x64."
        GN_ARGS_EXTRA_OS="target_cpu=\"x64\""
    else
        echo "⚠️ Unknown macOS architecture: $HOST_ARCH. Using default target_cpu from args.gn."
    fi
fi

# Feature flags
HENSURF_ENABLE_BLOATWARE=0 # Default to disabled
BUILD_CHROMEDRIVER=true
BUILD_MINI_INSTALLER=true

# Parse command-line arguments
# Use a while loop to handle shifting arguments correctly
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --enable-bloatware)
        HENSURF_ENABLE_BLOATWARE=1
        shift # past argument
        ;;
        --no-enable-bloatware)
        HENSURF_ENABLE_BLOATWARE=0
        shift # past argument
        ;;
        --skip-chromedriver)
        BUILD_CHROMEDRIVER=false
        shift # past argument
        ;;
        --skip-mini-installer)
        BUILD_MINI_INSTALLER=false
        shift # past argument
        ;;
        *)    # unknown option
        # Pass it along to gn gen or other parts of the script if necessary
        # For now, we'll just shift past it if it's not recognized here.
        shift # past argument
        ;;
    esac
done

GN_ARGS_LIST=()
if [[ -n "$GN_ARGS_EXTRA_OS" ]]; then
    GN_ARGS_LIST+=("$GN_ARGS_EXTRA_OS")
fi
GN_ARGS_LIST+=("hensurf_enable_bloatware=$HENSURF_ENABLE_BLOATWARE")

# Construct the final GN_ARGS_STRING
GN_ARGS_STRING=""
for item in "${GN_ARGS_LIST[@]}"; do
    if [[ -z "$GN_ARGS_STRING" ]]; then
        GN_ARGS_STRING="$item"
    else
        GN_ARGS_STRING="$GN_ARGS_STRING $item"
    fi
done

# Generate build files
echo "⚙️  Generating build files..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting gn generation..." | tee -a out/HenSurf/build.log # Tee to log
if [[ -n "$GN_ARGS_STRING" ]]; then
    echo "   With GN_ARGS: $GN_ARGS_STRING" | tee -a out/HenSurf/build.log
    gn gen out/HenSurf --args="$GN_ARGS_STRING" 2>&1 | tee -a out/HenSurf/build.log
else
    gn gen out/HenSurf 2>&1 | tee -a out/HenSurf/build.log
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished gn generation." | tee -a out/HenSurf/build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then # Check gn gen status
    echo "❌ Failed to generate build files. Check the configuration and build.log." | tee -a out/HenSurf/build.log
    exit 1
fi

# Show build configuration
echo "📋 Build configuration:" | tee -a out/HenSurf/build.log
gn args out/HenSurf --list --short 2>&1 | tee -a out/HenSurf/build.log

# Estimate build time
BASE_BUILD_HOURS=8
if [[ -n "$HENSURF_BASE_BUILD_HOURS" && "$HENSURF_BASE_BUILD_HOURS" =~ ^[0-9]+([.][0-9]+)?$ && $(echo "$HENSURF_BASE_BUILD_HOURS > 0" | bc -l) -eq 1 ]]; then
    BASE_BUILD_HOURS=$HENSURF_BASE_BUILD_HOURS
    echo "ℹ️ Using HENSURF_BASE_BUILD_HOURS=$HENSURF_BASE_BUILD_HOURS for estimation." | tee -a out/HenSurf/build.log
fi

# CPU_CORES is now determined OS-specifically above
ESTIMATED_HOURS=$(awk -v base="$BASE_BUILD_HOURS" -v cores="$CPU_CORES" 'BEGIN { printf "%.1f", base / cores }')
if (( $(echo "$ESTIMATED_HOURS < 0.5" | bc -l) )); then
    ESTIMATED_HOURS="<30 minutes"
elif (( $(echo "$ESTIMATED_HOURS < 1" | bc -l) )); then
    ESTIMATED_HOURS="<1 hour"
else
    ESTIMATED_HOURS=$(printf "%.0f hours" "$ESTIMATED_HOURS")
fi

echo "" | tee -a out/HenSurf/build.log
echo "🚀 Starting HenSurf build..." | tee -a out/HenSurf/build.log
echo "📊 System info:" | tee -a out/HenSurf/build.log
echo "   CPU cores: $CPU_CORES" | tee -a out/HenSurf/build.log
echo "   Memory: ${MEMORY_GB}GB" | tee -a out/HenSurf/build.log
echo "   Estimated time: ~${ESTIMATED_HOURS} (This is a VERY ROUGH estimate. Actual time can vary significantly based on system performance, specific configuration, and whether it's a clean or incremental build)." | tee -a out/HenSurf/build.log
echo "" | tee -a out/HenSurf/build.log
echo "⏳ This will take a while. You can monitor progress in another terminal with:" | tee -a out/HenSurf/build.log
echo "   tail -f chromium/src/out/HenSurf/build.log" | tee -a out/HenSurf/build.log
echo "" | tee -a out/HenSurf/build.log

# Start the build with logging (initial message already written if log file was new)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ensuring build log started." >> out/HenSurf/build.log # Append, don't overwrite if already exists

# Build HenSurf (chrome target)
echo "🔨 Building HenSurf browser..." | tee -a out/HenSurf/build.log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting main browser build (autoninja chrome)..." | tee -a out/HenSurf/build.log
echo "Ninja will now show detailed build progress (e.g., [X/Y] files compiled)..." | tee -a out/HenSurf/build.log
autoninja -C out/HenSurf chrome 2>&1 | tee -a out/HenSurf/build.log
CHROME_BUILD_STATUS=${PIPESTATUS[0]}
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished main browser build." | tee -a out/HenSurf/build.log

if [ $CHROME_BUILD_STATUS -ne 0 ]; then
    echo "❌ Build failed for chrome target. Check out/HenSurf/build.log for details." | tee -a out/HenSurf/build.log
    exit 1
fi

# Build additional components
if [ "$BUILD_CHROMEDRIVER" = true ]; then
    echo "🔨 Building chromedriver..." | tee -a out/HenSurf/build.log
    if [ -f "out/HenSurf/chromedriver" ]; then
        echo "ℹ️ chromedriver artifact already exists. Skipping build. Use --force-build-chromedriver to override." | tee -a out/HenSurf/build.log
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting chromedriver build (autoninja chromedriver)..." | tee -a out/HenSurf/build.log
        echo "Ninja will now show detailed build progress (e.g., [X/Y] files compiled)..." | tee -a out/HenSurf/build.log
        autoninja -C out/HenSurf chromedriver 2>&1 | tee -a out/HenSurf/build.log
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished chromedriver build." | tee -a out/HenSurf/build.log
    fi
else
    echo "ℹ️ Skipping chromedriver build as per --skip-chromedriver flag." | tee -a out/HenSurf/build.log
fi

# Create application bundle for macOS (and build macOS installer)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📦 Creating macOS application bundle..." | tee -a out/HenSurf/build.log # This part is for the main app bundle, not the installer yet.
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
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        echo "📦 Building macOS installer (dmg)..." | tee -a out/HenSurf/build.log
        # Simple check for existing DMG. A more robust check might look for any .dmg.
        DMG_CHECK_FILE=$(ls out/HenSurf/*.dmg 2>/dev/null | head -n 1)
        if [ -f "$DMG_CHECK_FILE" ]; then
            echo "ℹ️ macOS installer artifact ($DMG_CHECK_FILE) already exists. Skipping build. Use --force-build-installer to override." | tee -a out/HenSurf/build.log
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting macOS installer build (autoninja mini_installer)..." | tee -a out/HenSurf/build.log
            echo "Ninja will now show detailed build progress (e.g., [X/Y] files compiled)..." | tee -a out/HenSurf/build.log
            autoninja -C out/HenSurf mini_installer 2>&1 | tee -a out/HenSurf/build.log || echo "ℹ️  macOS installer build step finished (may have warnings or be skipped if not configured)." | tee -a out/HenSurf/build.log
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished macOS installer build." | tee -a out/HenSurf/build.log
        fi
    else
        echo "ℹ️ Skipping macOS installer build as per --skip-mini-installer flag." | tee -a out/HenSurf/build.log
    fi

elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        echo "📦 Building Windows installer (mini_installer)..." | tee -a out/HenSurf/build.log
        if [ -f "out/HenSurf/mini_installer.exe" ] || [ -f "out/HenSurf/setup.exe" ]; then
             echo "ℹ️ Windows installer artifact (mini_installer.exe or setup.exe) already exists. Skipping build. Use --force-build-installer to override." | tee -a out/HenSurf/build.log
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Windows installer build (autoninja mini_installer)..." | tee -a out/HenSurf/build.log
            echo "Ninja will now show detailed build progress (e.g., [X/Y] files compiled)..." | tee -a out/HenSurf/build.log
            autoninja -C out/HenSurf mini_installer 2>&1 | tee -a out/HenSurf/build.log || echo "ℹ️  Windows installer build step finished (may have warnings or be skipped if not configured)." | tee -a out/HenSurf/build.log
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished Windows installer build." | tee -a out/HenSurf/build.log
        fi
        # Check for common installer names after attempting build (if not skipped)
        if [ -f "out/HenSurf/mini_installer.exe" ]; then
            echo "✅ Windows mini_installer.exe found." | tee -a out/HenSurf/build.log
        elif [ -f "out/HenSurf/setup.exe" ]; then
            echo "✅ Windows setup.exe found." | tee -a out/HenSurf/build.log
        else
            echo "⚠️  Windows installer (mini_installer.exe or setup.exe) not found in out/HenSurf/." | tee -a out/HenSurf/build.log
        fi
    else
        echo "ℹ️ Skipping Windows installer build as per --skip-mini-installer flag." | tee -a out/HenSurf/build.log
    fi
fi # End of OS specific bundling

echo ""
echo "🎉 HenSurf build completed successfully!"
echo ""
echo "📍 Build artifacts location (relative to $CHROMIUM_SRC_DIR):"
echo "   Main executable: out/HenSurf/chrome${EXE_SUFFIX}" # EXE_SUFFIX will be .exe on windows, empty otherwise

if [ "$BUILD_CHROMEDRIVER" = true ] && [ -f "out/HenSurf/chromedriver${EXE_SUFFIX}" ]; then
    echo "   ChromeDriver:    out/HenSurf/chromedriver${EXE_SUFFIX}"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "out/HenSurf/HenSurf.app" ]; then # This is the main app bundle
        echo "   macOS App Bundle: out/HenSurf/HenSurf.app"
    fi
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        DMG_FILE=$(ls out/HenSurf/*.dmg 2>/dev/null | head -n 1)
        if [ -f "$DMG_FILE" ]; then
            echo "   macOS Installer:  $(basename "$DMG_FILE") (in out/HenSurf/)"
        elif [ -f "out/HenSurf/HenSurf.dmg" ]; then # Fallback to generic name
             echo "   macOS Installer:  HenSurf.dmg (in out/HenSurf/)"
        fi
    fi
elif [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]]; then
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
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