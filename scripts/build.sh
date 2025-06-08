#!/bin/bash

# HenSurf Browser - Build Script
# This script builds HenSurf from the customized Chromium source

set -e

# Source utility functions
SCRIPT_DIR_BUILD=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR_BUILD/utils.sh"

# Define Project Root and log file path (relative to project root)
PROJECT_ROOT=$(cd "$SCRIPT_DIR_BUILD/.." &>/dev/null && pwd)
CHROMIUM_SRC_DIR="$PROJECT_ROOT/chromium/src" # Define early for log path
BUILD_LOG_FILE="$CHROMIUM_SRC_DIR/out/HenSurf/build.log" # Log inside out/HenSurf

# Ensure out/HenSurf directory exists for the log file
mkdir -p "$CHROMIUM_SRC_DIR/out/HenSurf"
# Clear previous log file or create if not exists
>"$BUILD_LOG_FILE"


log_info "🔨 Building HenSurf Browser..." | tee -a "$BUILD_LOG_FILE"

# Check if Chromium source exists
if [ ! -d "$CHROMIUM_SRC_DIR" ]; then
    log_error "❌ Chromium source not found at $CHROMIUM_SRC_DIR. Please run ./scripts/fetch-chromium.sh first." | tee -a "$BUILD_LOG_FILE"
    exit 1
fi
log_success "✅ Chromium source directory found: $CHROMIUM_SRC_DIR" | tee -a "$BUILD_LOG_FILE"

# Check if patches have been applied (args.gn is a good indicator)
if [ ! -f "$CHROMIUM_SRC_DIR/out/HenSurf/args.gn" ]; then
    log_error "❌ HenSurf configuration (args.gn) not found in $CHROMIUM_SRC_DIR/out/HenSurf. Please run ./scripts/apply-patches.sh first." | tee -a "$BUILD_LOG_FILE"
    exit 1
fi
log_success "✅ HenSurf configuration (args.gn) found." | tee -a "$BUILD_LOG_FILE"


# Depot Tools Setup
DEPOT_TOOLS_DIR=$(get_depot_tools_dir "$PROJECT_ROOT")
if [ -z "$DEPOT_TOOLS_DIR" ]; then
    log_error "Failed to determine depot_tools directory path. Exiting." | tee -a "$BUILD_LOG_FILE"
    exit 1
fi
if ! add_depot_tools_to_path "$DEPOT_TOOLS_DIR"; then
    log_error "Failed to add depot_tools to PATH. Exiting." | tee -a "$BUILD_LOG_FILE"
    # add_depot_tools_to_path already logs details to stdout, which will be in the main log if script output is captured.
    exit 1
fi
# add_depot_tools_to_path already logs success and checks for gn/autoninja

# Configure ccache
export CCACHE_CPP2=true
export CCACHE_SLOPPINESS="time_macros"
# Optional: export CCACHE_DIR="/path/to/your/ccache_directory" (log if set)
if [ -n "$CCACHE_DIR" ]; then
    log_info "ℹ️ Using custom CCACHE_DIR: $CCACHE_DIR" | tee -a "$BUILD_LOG_FILE"
fi

# Verify ccache is found and print stats
if command_exists "ccache"; then
    log_success "✅ ccache found: $(command -v ccache)" | tee -a "$BUILD_LOG_FILE"
    log_info "Initial ccache statistics:" | tee -a "$BUILD_LOG_FILE"
    ccache -s 2>&1 | tee -a "$BUILD_LOG_FILE"
else
    log_warn "⚠️ ccache command not found. Build will proceed without ccache (ensure use_ccache is false in args.gn or ccache is installed)." | tee -a "$BUILD_LOG_FILE"
fi

# Navigate to the chromium source directory
cd "$CHROMIUM_SRC_DIR"
log_info "Current directory: $(pwd)" | tee -a "$BUILD_LOG_FILE"


# Check system requirements
log_info "🔍 Checking system requirements..." | tee -a "$BUILD_LOG_FILE"
OS_TYPE_BUILD=$(get_os_type)
MEMORY_GB=0
CPU_CORES=1 # Default to 1 core if detection fails

case "$OS_TYPE_BUILD" in
    "macos")
        log_info "🍏 Checking macOS system requirements..." | tee -a "$BUILD_LOG_FILE"
        MEMORY_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
        CPU_CORES=$(sysctl -n hw.ncpu)
        ;;
    "linux")
        log_info "🐧 Checking Linux system requirements..." | tee -a "$BUILD_LOG_FILE"
        if [ -f /proc/meminfo ]; then
            MEMORY_GB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
        else # Fallback for systems without /proc/meminfo but might have 'free'
            MEMORY_KB=$(free | grep Mem: | awk '{print $2}')
            if [[ "$MEMORY_KB" =~ ^[0-9]+$ ]]; then
                MEMORY_GB=$(awk -v memkb="$MEMORY_KB" 'BEGIN { printf "%.0f", memkb / 1024 / 1024 }')
            else
                log_warn "⚠️ Could not determine system memory from /proc/meminfo or free." | tee -a "$BUILD_LOG_FILE"
            fi
        fi
        if command_exists "nproc"; then
            CPU_CORES=$(nproc)
        else
            CPU_CORES=$(grep -c ^processor /proc/cpuinfo || echo 1) # Fallback for CPU cores
            log_warn "⚠️ nproc command not found, using /proc/cpuinfo or defaulting to $CPU_CORES CPU core(s) for estimates." | tee -a "$BUILD_LOG_FILE"
        fi
        ;;
    "windows")
        log_info "💻 Checking Windows system requirements..." | tee -a "$BUILD_LOG_FILE"
        if ! command_exists "wmic"; then
            log_warn "⚠️ 'wmic' command not found. Cannot check system requirements accurately." | tee -a "$BUILD_LOG_FILE"
            MEMORY_GB=0
            CPU_CORES=1
        else
            TOTAL_MEM_KB_STR=$(wmic OS get TotalVisibleMemorySize /value | tr -d '\r' | grep TotalVisibleMemorySize | cut -d'=' -f2)
            if [[ -n "$TOTAL_MEM_KB_STR" && "$TOTAL_MEM_KB_STR" =~ ^[0-9]+$ ]]; then
                MEMORY_GB=$(awk -v memkb="$TOTAL_MEM_KB_STR" 'BEGIN { printf "%.0f", memkb / 1024 / 1024 }')
            else
                log_warn "⚠️ Could not determine TotalVisibleMemorySize using wmic. Output: '$TOTAL_MEM_KB_STR'" | tee -a "$BUILD_LOG_FILE"
                MEMORY_GB=0
            fi

            CPU_CORES_STR=$(wmic cpu get NumberOfLogicalProcessors /value | tr -d '\r' | grep NumberOfLogicalProcessors | cut -d'=' -f2)
            if [[ -n "$CPU_CORES_STR" && "$CPU_CORES_STR" =~ ^[0-9]+$ ]]; then
                CPU_CORES=$CPU_CORES_STR
            else
                log_warn "⚠️ Could not determine NumberOfLogicalProcessors using wmic. Output: '$CPU_CORES_STR'" | tee -a "$BUILD_LOG_FILE"
                CPU_CORES=1
            fi
        fi
        ;;
    *)
        log_warn "⚠️ Unsupported OS ($OS_TYPE_BUILD) for detailed system checks. Proceeding with default assumptions (0GB RAM, 1 CPU core)." | tee -a "$BUILD_LOG_FILE"
        MEMORY_GB=0
        CPU_CORES=1
        ;;
esac
log_info "   Detected RAM: ${MEMORY_GB}GB, CPU Cores: $CPU_CORES" | tee -a "$BUILD_LOG_FILE"

MIN_RAM_GB=16
if [ "$MEMORY_GB" -lt "$MIN_RAM_GB" ]; then
    if [ "$MEMORY_GB" -gt 0 ]; then
        log_warn "⚠️  Warning: Only ${MEMORY_GB}GB RAM detected. ${MIN_RAM_GB}GB+ recommended for building Chromium." | tee -a "$BUILD_LOG_FILE"
    elif [[ "$OS_TYPE_BUILD" == "windows" || "$OS_TYPE_BUILD" == "macos" || "$OS_TYPE_BUILD" == "linux" ]]; then
        log_warn "⚠️  Warning: Could not reliably determine system RAM. ${MIN_RAM_GB}GB+ recommended for building Chromium." | tee -a "$BUILD_LOG_FILE"
    fi
    if [[ "$OS_TYPE_BUILD" == "windows" || "$OS_TYPE_BUILD" == "macos" || "$OS_TYPE_BUILD" == "linux" || "$MEMORY_GB" -gt 0 ]]; then
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "User aborted due to low RAM." | tee -a "$BUILD_LOG_FILE"
            exit 1
        fi
    fi
fi

# Check available disk space
MIN_BUILD_DISK_SPACE_GB=50
AVAILABLE_SPACE_GB=0

case "$OS_TYPE_BUILD" in
    "macos"|"linux")
        AVAILABLE_SPACE_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//' | tr -d '[:space:]')
        log_info "Disk space check ($OS_TYPE_BUILD): ${AVAILABLE_SPACE_GB}GB available in $(pwd)." | tee -a "$BUILD_LOG_FILE"
        ;;
    "windows")
        log_info "💻 Checking disk space on Windows in $(pwd)..." | tee -a "$BUILD_LOG_FILE"
        CURRENT_DRIVE_LETTER_BUILD=$(pwd -W | cut -d':' -f1)
        if ! command_exists "wmic"; then
            log_warn "⚠️ 'wmic' command not found. Cannot check disk space accurately on Windows." | tee -a "$BUILD_LOG_FILE"
            AVAILABLE_SPACE_GB=0
        else
            AVAILABLE_BYTES_STR_BUILD=$(wmic logicaldisk where "DeviceID='${CURRENT_DRIVE_LETTER_BUILD}:'" get FreeSpace /value | tr -d '\r' | grep FreeSpace | cut -d'=' -f2)
            if [[ -z "$AVAILABLE_BYTES_STR_BUILD" || ! "$AVAILABLE_BYTES_STR_BUILD" =~ ^[0-9]+$ ]]; then
                 log_warn "⚠️ Could not determine free space using wmic for drive ${CURRENT_DRIVE_LETTER_BUILD}: (Output: '$AVAILABLE_BYTES_STR_BUILD')." | tee -a "$BUILD_LOG_FILE"
                 AVAILABLE_SPACE_GB=0
            else
                AVAILABLE_SPACE_GB=$(awk -v bytes="$AVAILABLE_BYTES_STR_BUILD" 'BEGIN { printf "%.0f", bytes / 1024 / 1024 / 1024 }')
            fi
        fi
        log_info "Drive ${CURRENT_DRIVE_LETTER_BUILD}: has approximately ${AVAILABLE_SPACE_GB}GB free." | tee -a "$BUILD_LOG_FILE"
        ;;
    *)
        log_warn "⚠️ Unsupported OS for disk space check: $OS_TYPE_BUILD. Assuming ${MIN_BUILD_DISK_SPACE_GB}GB available." | tee -a "$BUILD_LOG_FILE"
        AVAILABLE_SPACE_GB=${MIN_BUILD_DISK_SPACE_GB} # Assume enough for unknown OS
        ;;
esac

if ! [[ "$AVAILABLE_SPACE_GB" =~ ^[0-9]+$ ]]; then # Sanitize if not a number
    log_warn "⚠️ Could not reliably determine available disk space in $(pwd). Detected: '$AVAILABLE_SPACE_GB'." | tee -a "$BUILD_LOG_FILE"
    AVAILABLE_SPACE_GB=0
fi

if [ "$AVAILABLE_SPACE_GB" -lt "$MIN_BUILD_DISK_SPACE_GB" ]; then
    log_warn "⚠️  Warning: Only ${AVAILABLE_SPACE_GB}GB detected as available in $(pwd). Build output requires ~${MIN_BUILD_DISK_SPACE_GB}GB." | tee -a "$BUILD_LOG_FILE"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "User aborted due to low disk space." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
fi

# Determine target_cpu for macOS
GN_ARGS_EXTRA_OS=""
if [[ "$OS_TYPE_BUILD" == "macos" ]]; then
    HOST_ARCH=$(uname -m)
    if [[ "$HOST_ARCH" == "arm64" ]]; then
        log_info "🍏 Detected Apple Silicon (arm64). Setting target_cpu=arm64." | tee -a "$BUILD_LOG_FILE"
        GN_ARGS_EXTRA_OS="target_cpu=\"arm64\""
    elif [[ "$HOST_ARCH" == "x86_64" ]]; then
        log_info "🍏 Detected Intel (x86_64). Setting target_cpu=x64." | tee -a "$BUILD_LOG_FILE"
        GN_ARGS_EXTRA_OS="target_cpu=\"x64\""
    else
        log_warn "⚠️ Unknown macOS architecture: $HOST_ARCH. Using default target_cpu from args.gn." | tee -a "$BUILD_LOG_FILE"
    fi
fi

# Feature flags
HENSURF_ENABLE_BLOATWARE=0 # Default to disabled
BUILD_CHROMEDRIVER=true
BUILD_MINI_INSTALLER=true
DEV_FAST_MODE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --enable-bloatware) HENSURF_ENABLE_BLOATWARE=1; shift ;;
        --no-enable-bloatware) HENSURF_ENABLE_BLOATWARE=0; shift ;;
        --skip-chromedriver) BUILD_CHROMEDRIVER=false; shift ;;
        --skip-mini-installer) BUILD_MINI_INSTALLER=false; shift ;;
        --dev-fast) DEV_FAST_MODE=true; shift ;;
        *) shift ;; # unknown option
    esac
done

GN_ARGS_LIST=()
if [ "$DEV_FAST_MODE" = true ]; then
    log_info "🚀 Developer Fast Mode enabled: is_component_build=true, treat_warnings_as_errors=false" | tee -a "$BUILD_LOG_FILE"
    GN_ARGS_LIST+=("is_component_build=true")
    GN_ARGS_LIST+=("treat_warnings_as_errors=false")
fi
if [[ -n "$GN_ARGS_EXTRA_OS" ]]; then
    GN_ARGS_LIST+=("$GN_ARGS_EXTRA_OS")
fi
GN_ARGS_LIST+=("hensurf_enable_bloatware=$HENSURF_ENABLE_BLOATWARE")

GN_ARGS_STRING=""
for item in "${GN_ARGS_LIST[@]}"; do
    [[ -z "$GN_ARGS_STRING" ]] && GN_ARGS_STRING="$item" || GN_ARGS_STRING="$GN_ARGS_STRING $item"
done

# Generate build files
log_info "⚙️  Generating build files..." | tee -a "$BUILD_LOG_FILE"
log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting gn generation..." | tee -a "$BUILD_LOG_FILE"
if [[ -n "$GN_ARGS_STRING" ]]; then
    log_info "   With GN_ARGS: $GN_ARGS_STRING" | tee -a "$BUILD_LOG_FILE"
    gn gen out/HenSurf --args="$GN_ARGS_STRING" 2>&1 | tee -a "$BUILD_LOG_FILE"
else
    gn gen out/HenSurf 2>&1 | tee -a "$BUILD_LOG_FILE"
fi
GN_GEN_STATUS=${PIPESTATUS[0]}
log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished gn generation." | tee -a "$BUILD_LOG_FILE"

if [ $GN_GEN_STATUS -ne 0 ]; then
    log_error "❌ Failed to generate build files. Check the configuration and $BUILD_LOG_FILE." | tee -a "$BUILD_LOG_FILE"
    exit 1
fi

# Show build configuration
log_info "📋 Build configuration:" | tee -a "$BUILD_LOG_FILE"
gn args out/HenSurf --list --short 2>&1 | tee -a "$BUILD_LOG_FILE"

# Estimate build time
BASE_BUILD_HOURS=8
if [[ -n "$HENSURF_BASE_BUILD_HOURS" && "$HENSURF_BASE_BUILD_HOURS" =~ ^[0-9]+([.][0-9]+)?$ && $(echo "$HENSURF_BASE_BUILD_HOURS > 0" | bc -l) -eq 1 ]]; then
    BASE_BUILD_HOURS=$HENSURF_BASE_BUILD_HOURS
    log_info "ℹ️ Using HENSURF_BASE_BUILD_HOURS=$HENSURF_BASE_BUILD_HOURS for estimation." | tee -a "$BUILD_LOG_FILE"
fi

ESTIMATED_HOURS=$(awk -v base="$BASE_BUILD_HOURS" -v cores="$CPU_CORES" 'BEGIN { printf "%.1f", base / cores }')
if (( $(echo "$ESTIMATED_HOURS < 0.5" | bc -l) )); then ESTIMATED_HOURS="<30 minutes";
elif (( $(echo "$ESTIMATED_HOURS < 1" | bc -l) )); then ESTIMATED_HOURS="<1 hour";
else ESTIMATED_HOURS=$(printf "%.0f hours" "$ESTIMATED_HOURS"); fi

log_info "" | tee -a "$BUILD_LOG_FILE"
log_info "🚀 Starting HenSurf build..." | tee -a "$BUILD_LOG_FILE"
log_info "📊 System info:" | tee -a "$BUILD_LOG_FILE"
log_info "   CPU cores: $CPU_CORES" | tee -a "$BUILD_LOG_FILE"
log_info "   Memory: ${MEMORY_GB}GB" | tee -a "$BUILD_LOG_FILE"
log_info "   Estimated time: ~${ESTIMATED_HOURS} (This is a VERY ROUGH estimate.)" | tee -a "$BUILD_LOG_FILE"
log_info "" | tee -a "$BUILD_LOG_FILE"
log_info "⏳ This will take a while. You can monitor progress in another terminal with:" | tee -a "$BUILD_LOG_FILE"
log_info "   tail -f $BUILD_LOG_FILE" | tee -a "$BUILD_LOG_FILE" # Corrected log file path
log_info "" | tee -a "$BUILD_LOG_FILE"

# Build HenSurf (chrome target)
log_info "🔨 Building HenSurf browser..." | tee -a "$BUILD_LOG_FILE"
log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting main browser build (autoninja chrome)..." | tee -a "$BUILD_LOG_FILE"
log_info "Ninja will now show detailed build progress (e.g., [X/Y] files compiled)..." | tee -a "$BUILD_LOG_FILE"
autoninja -C out/HenSurf chrome 2>&1 | tee -a "$BUILD_LOG_FILE"
CHROME_BUILD_STATUS=${PIPESTATUS[0]}
log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished main browser build." | tee -a "$BUILD_LOG_FILE"

if command_exists "ccache"; then
    log_info "Final ccache statistics after main browser build:" | tee -a "$BUILD_LOG_FILE"
    ccache -s 2>&1 | tee -a "$BUILD_LOG_FILE"
fi

if [ $CHROME_BUILD_STATUS -ne 0 ]; then
    log_error "❌ Build failed for chrome target. Check $BUILD_LOG_FILE for details." | tee -a "$BUILD_LOG_FILE"
    exit 1
fi

# Build additional components
EXE_SUFFIX=""
[[ "$OS_TYPE_BUILD" == "windows" ]] && EXE_SUFFIX=".exe"

if [ "$BUILD_CHROMEDRIVER" = true ]; then
    log_info "🔨 Building chromedriver..." | tee -a "$BUILD_LOG_FILE"
    if [ -f "out/HenSurf/chromedriver$EXE_SUFFIX" ]; then
        log_info "ℹ️ chromedriver artifact already exists. Skipping build." | tee -a "$BUILD_LOG_FILE"
    else
        log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting optional component build: chromedriver..." | tee -a "$BUILD_LOG_FILE"
        autoninja -C out/HenSurf chromedriver 2>&1 | tee -a "$BUILD_LOG_FILE"
        CHROMEDRIVER_BUILD_STATUS=${PIPESTATUS[0]}
        if [[ $CHROMEDRIVER_BUILD_STATUS -ne 0 ]]; then
            log_warn "⚠️ Optional component chromedriver failed to build (exit code $CHROMEDRIVER_BUILD_STATUS). Continuing with the main build." | tee -a "$BUILD_LOG_FILE"
        else
            log_success "✅ Optional component chromedriver built successfully." | tee -a "$BUILD_LOG_FILE"
        fi
        log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished optional component build: chromedriver." | tee -a "$BUILD_LOG_FILE"
    fi
else
    log_info "ℹ️ Skipping chromedriver build as per --skip-chromedriver flag." | tee -a "$BUILD_LOG_FILE"
fi

# Create application bundle for macOS (and build macOS installer)
if [[ "$OS_TYPE_BUILD" == "macos" ]]; then
    log_info "📦 Creating macOS application bundle..." | tee -a "$BUILD_LOG_FILE"
    if [ -d "out/HenSurf/HenSurf.app" ]; then
        rm -rf out/HenSurf/HenSurf.app
    fi

    EXPECTED_CHROMIUM_APP_NAME="Chromium.app" # Default app name for is_chrome_branded=false
    APP_COPIED=false
    if [ -d "out/HenSurf/${EXPECTED_CHROMIUM_APP_NAME}" ]; then
        log_info "Found ${EXPECTED_CHROMIUM_APP_NAME}, copying to HenSurf.app..." | tee -a "$BUILD_LOG_FILE"
        cp -R "out/HenSurf/${EXPECTED_CHROMIUM_APP_NAME}" "out/HenSurf/HenSurf.app"
        APP_COPIED=true
    fi

    if [ "$APP_COPIED" = true ] && [ -d "out/HenSurf/HenSurf.app" ]; then
        PLIST_BUDDY="/usr/libexec/PlistBuddy"
        INFO_PLIST="out/HenSurf/HenSurf.app/Contents/Info.plist"
        # Values from hensurf.gn or project defaults
        TARGET_MACOS_VERSION="10.15"
        HENSURF_VERSION="1.0.0"
        HENSURF_BUILD_NUMBER="1"

        if command_exists "$PLIST_BUDDY" && [ -f "$INFO_PLIST" ]; then
            log_info "Updating Info.plist at: $INFO_PLIST" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleName HenSurf" "$INFO_PLIST" 2>/dev/null || log_warn "Warning: Failed to set CFBundleName" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleDisplayName HenSurf Browser" "$INFO_PLIST" 2>/dev/null || log_warn "Warning: Failed to set CFBundleDisplayName" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleIdentifier com.hensurf.browser" "$INFO_PLIST" 2>/dev/null || log_warn "Warning: Failed to set CFBundleIdentifier" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $HENSURF_VERSION" "$INFO_PLIST" 2>/dev/null || log_warn "Warning: Failed to set CFBundleShortVersionString" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleVersion $HENSURF_BUILD_NUMBER" "$INFO_PLIST" 2>/dev/null || log_warn "Warning: Failed to set CFBundleVersion" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :LSMinimumSystemVersion $TARGET_MACOS_VERSION" "$INFO_PLIST" 2>/dev/null || log_warn "Warning: Failed to set LSMinimumSystemVersion" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleIconFile app.icns" "$INFO_PLIST" 2>/dev/null || log_warn "Warning: Failed to set CFBundleIconFile" | tee -a "$BUILD_LOG_FILE"
            log_success "✅ HenSurf.app bundle created and Info.plist configured successfully!" | tee -a "$BUILD_LOG_FILE"
        else
            log_warn "⚠️  PlistBuddy tool ($PLIST_BUDDY) or Info.plist ($INFO_PLIST) not found. Cannot customize app bundle." | tee -a "$BUILD_LOG_FILE"
        fi
    else
        log_warn "⚠️  Could not find the expected base app bundle '${EXPECTED_CHROMIUM_APP_NAME}' in out/HenSurf/ to create HenSurf.app." | tee -a "$BUILD_LOG_FILE"
    fi

    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        log_info "📦 Building macOS installer (dmg)..." | tee -a "$BUILD_LOG_FILE"
        DMG_CHECK_FILE=$(ls out/HenSurf/*.dmg 2>/dev/null | head -n 1)
        if [ -f "$DMG_CHECK_FILE" ]; then
            log_info "ℹ️ macOS installer artifact ($DMG_CHECK_FILE) already exists. Skipping build." | tee -a "$BUILD_LOG_FILE"
        else
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting optional component build: macOS mini_installer..." | tee -a "$BUILD_LOG_FILE"
            autoninja -C out/HenSurf mini_installer 2>&1 | tee -a "$BUILD_LOG_FILE"
            MINI_INSTALLER_MACOS_BUILD_STATUS=${PIPESTATUS[0]}
            if [[ $MINI_INSTALLER_MACOS_BUILD_STATUS -ne 0 ]]; then
                log_warn "⚠️ Optional component macOS mini_installer failed to build (exit code $MINI_INSTALLER_MACOS_BUILD_STATUS). Continuing." | tee -a "$BUILD_LOG_FILE"
            else
                log_success "✅ Optional component macOS mini_installer built successfully." | tee -a "$BUILD_LOG_FILE"
            fi
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished optional component build: macOS mini_installer." | tee -a "$BUILD_LOG_FILE"
        fi
    else
        log_info "ℹ️ Skipping macOS installer build as per --skip-mini-installer flag." | tee -a "$BUILD_LOG_FILE"
    fi

elif [[ "$OS_TYPE_BUILD" == "windows" ]]; then
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        log_info "📦 Building Windows installer (mini_installer)..." | tee -a "$BUILD_LOG_FILE"
        if [ -f "out/HenSurf/mini_installer.exe" ] || [ -f "out/HenSurf/setup.exe" ]; then
             log_info "ℹ️ Windows installer artifact (mini_installer.exe or setup.exe) already exists. Skipping build." | tee -a "$BUILD_LOG_FILE"
        else
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting optional component build: Windows mini_installer..." | tee -a "$BUILD_LOG_FILE"
            autoninja -C out/HenSurf mini_installer 2>&1 | tee -a "$BUILD_LOG_FILE"
            MINI_INSTALLER_WIN_BUILD_STATUS=${PIPESTATUS[0]}
            if [[ $MINI_INSTALLER_WIN_BUILD_STATUS -ne 0 ]]; then
                log_warn "⚠️ Optional component Windows mini_installer failed to build (exit code $MINI_INSTALLER_WIN_BUILD_STATUS). Continuing." | tee -a "$BUILD_LOG_FILE"
            else
                log_success "✅ Optional component Windows mini_installer built successfully." | tee -a "$BUILD_LOG_FILE"
            fi
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished optional component build: Windows mini_installer." | tee -a "$BUILD_LOG_FILE"
        fi
        if [ -f "out/HenSurf/mini_installer.exe" ]; then
            log_success "✅ Windows mini_installer.exe found." | tee -a "$BUILD_LOG_FILE"
        elif [ -f "out/HenSurf/setup.exe" ]; then
            log_success "✅ Windows setup.exe found." | tee -a "$BUILD_LOG_FILE"
        else
            # This warning is valid if the build was attempted and failed, or if it succeeded but produced an unexpected name.
            # If the build was skipped, this warning might be misleading.
            # However, the current logic attempts build only if not found, so this should be okay.
            log_warn "⚠️  Windows installer (mini_installer.exe or setup.exe) not found in out/HenSurf/ after build attempt." | tee -a "$BUILD_LOG_FILE"
        fi
    else
        log_info "ℹ️ Skipping Windows installer build as per --skip-mini-installer flag." | tee -a "$BUILD_LOG_FILE"
    fi
fi

log_info "" | tee -a "$BUILD_LOG_FILE"
log_success "🎉 HenSurf build completed successfully!" | tee -a "$BUILD_LOG_FILE"
log_info "" | tee -a "$BUILD_LOG_FILE"
log_info "📍 Build artifacts location (relative to $CHROMIUM_SRC_DIR):" | tee -a "$BUILD_LOG_FILE"
log_info "   Main executable: out/HenSurf/chrome${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"

if [ "$BUILD_CHROMEDRIVER" = true ] && [ -f "out/HenSurf/chromedriver${EXE_SUFFIX}" ]; then
    log_info "   ChromeDriver:    out/HenSurf/chromedriver${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"
fi

if [[ "$OS_TYPE_BUILD" == "macos" ]]; then
    if [ -d "out/HenSurf/HenSurf.app" ]; then
        log_info "   macOS App Bundle: out/HenSurf/HenSurf.app" | tee -a "$BUILD_LOG_FILE"
    fi
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        DMG_FILE=$(ls out/HenSurf/*.dmg 2>/dev/null | head -n 1)
        if [ -f "$DMG_FILE" ]; then
            log_info "   macOS Installer:  $(basename "$DMG_FILE") (in out/HenSurf/)" | tee -a "$BUILD_LOG_FILE"
        elif [ -f "out/HenSurf/HenSurf.dmg" ]; then
             log_info "   macOS Installer:  HenSurf.dmg (in out/HenSurf/)" | tee -a "$BUILD_LOG_FILE"
        fi
    fi
elif [[ "$OS_TYPE_BUILD" == "windows" ]]; then
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        if [ -f "out/HenSurf/mini_installer.exe" ]; then
            log_info "   Windows Installer: out/HenSurf/mini_installer.exe" | tee -a "$BUILD_LOG_FILE"
        elif [ -f "out/HenSurf/setup.exe" ]; then
            log_info "   Windows Installer: out/HenSurf/setup.exe" | tee -a "$BUILD_LOG_FILE"
        else
            WIN_INSTALLER_FILE=$(ls out/HenSurf/*installer.exe 2>/dev/null | head -n 1)
            if [ -f "$WIN_INSTALLER_FILE" ]; then
                 log_info "   Windows Installer: $(basename "$WIN_INSTALLER_FILE") (in out/HenSurf/)" | tee -a "$BUILD_LOG_FILE"
            fi
        fi
    fi
fi
log_info "   Build log: $BUILD_LOG_FILE" | tee -a "$BUILD_LOG_FILE" # Corrected log file path
log_info "" | tee -a "$BUILD_LOG_FILE"
log_info "🚀 To run HenSurf (from $CHROMIUM_SRC_DIR directory):" | tee -a "$BUILD_LOG_FILE"

if [[ "$OS_TYPE_BUILD" == "macos" ]]; then
    if [ -d "out/HenSurf/HenSurf.app" ]; then
        log_info "   open out/HenSurf/HenSurf.app" | tee -a "$BUILD_LOG_FILE"
    else
        log_info "   ./out/HenSurf/chrome  (App bundle creation failed or was skipped)" | tee -a "$BUILD_LOG_FILE"
    fi
elif [[ "$OS_TYPE_BUILD" == "windows" ]]; then
    log_info "   ./out/HenSurf/chrome${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"
else
    log_info "   ./out/HenSurf/chrome" | tee -a "$BUILD_LOG_FILE"
fi
log_info "" | tee -a "$BUILD_LOG_FILE"
log_info "📋 HenSurf features:" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ No AI-powered suggestions" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ No Google services integration" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ DuckDuckGo as default search" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ Enhanced privacy settings" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ Minimal telemetry" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ Clean, bloatware-free interface" | tee -a "$BUILD_LOG_FILE"