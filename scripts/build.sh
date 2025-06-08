#!/bin/bash

# HenSurf Browser - Build Script
# This script builds HenSurf from the customized Chromium source

set -e

# Source utility functions
SCRIPT_DIR_BUILD=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR_BUILD/utils.sh"

# Define Project Root
PROJECT_ROOT=$(cd "$SCRIPT_DIR_BUILD/.." &>/dev/null && pwd)
CHROMIUM_SRC_DIR="$PROJECT_ROOT/chromium/src"

# --- Environment Variable Handling & Default Values ---
HOST_OS_TYPE=$(get_os_type) # Used for native defaults

# Determine FINAL_TARGET_OS
if [ -z "$HENSURF_TARGET_OS" ]; then
    FINAL_TARGET_OS="$HOST_OS_TYPE"
    log_info "HENSURF_TARGET_OS not set, defaulting to native OS: $FINAL_TARGET_OS"
else
    FINAL_TARGET_OS="$HENSURF_TARGET_OS"
    log_info "Using HENSURF_TARGET_OS: $FINAL_TARGET_OS"
fi

# Determine FINAL_TARGET_CPU
if [ -z "$HENSURF_TARGET_CPU" ]; then
    NATIVE_CPU_ARCH=""
    if [[ "$HOST_OS_TYPE" == "mac" ]]; then
        _UNAME_M_OUTPUT=$(uname -m)
        if [[ "$_UNAME_M_OUTPUT" == "x86_64" ]]; then
            NATIVE_CPU_ARCH="x64"
        elif [[ "$_UNAME_M_OUTPUT" == "arm64" ]]; then
            NATIVE_CPU_ARCH="arm64"
        else
            log_warn "Unknown macOS arch from uname -m: $_UNAME_M_OUTPUT. Defaulting to x64."
            NATIVE_CPU_ARCH="x64" # Default for unknown Mac arch
        fi
    elif [[ "$HOST_OS_TYPE" == "linux" ]]; then
        _UNAME_M_OUTPUT=$(uname -m)
        if [[ "$_UNAME_M_OUTPUT" == "x86_64" ]]; then NATIVE_CPU_ARCH="x64";
        elif [[ "$_UNAME_M_OUTPUT" == "aarch64" ]]; then NATIVE_CPU_ARCH="arm64";
        elif [[ "$_UNAME_M_OUTPUT" == "armv7l" ]]; then NATIVE_CPU_ARCH="arm"; # example for 32-bit arm
        else NATIVE_CPU_ARCH="x64"; log_warn "Unknown Linux arch: $_UNAME_M_OUTPUT. Defaulting to x64."; fi
    elif [[ "$HOST_OS_TYPE" == "win" ]]; then
        if [[ "$PROCESSOR_ARCHITECTURE" == "AMD64" ]] || [[ "$PROCESSOR_ARCHITECTURE" == "EM64T" ]]; then NATIVE_CPU_ARCH="x64";
        elif [[ "$PROCESSOR_ARCHITECTURE" == "ARM64" ]]; then NATIVE_CPU_ARCH="arm64";
        # Add more Windows arch checks if necessary, e.g. x86
        else NATIVE_CPU_ARCH="x64"; log_warn "Unknown Windows arch: $PROCESSOR_ARCHITECTURE. Defaulting to x64."; fi
    else
        log_warn "Unknown host OS type: $HOST_OS_TYPE. Defaulting target CPU to x64."
        NATIVE_CPU_ARCH="x64" # Fallback for unknown OS
    fi
    FINAL_TARGET_CPU="$NATIVE_CPU_ARCH"
    log_info "HENSURF_TARGET_CPU not set, defaulting to detected native CPU: $FINAL_TARGET_CPU for host OS $HOST_OS_TYPE"
else
    FINAL_TARGET_CPU="$HENSURF_TARGET_CPU"
    log_info "Using HENSURF_TARGET_CPU: $FINAL_TARGET_CPU"
fi

# Determine FINAL_OUTPUT_DIR
if [ -z "$HENSURF_OUTPUT_DIR" ]; then
    # Default output dir includes OS and CPU if they were determined (even if defaulted from native)
    # Ensure FINAL_TARGET_OS and FINAL_TARGET_CPU are non-empty before forming the path.
    _DEFAULT_OS_FOR_PATH=${FINAL_TARGET_OS:-"unknownOS"}
    _DEFAULT_CPU_FOR_PATH=${FINAL_TARGET_CPU:-"unknownCPU"}
    FINAL_OUTPUT_DIR="out/HenSurf-${_DEFAULT_OS_FOR_PATH}-${_DEFAULT_CPU_FOR_PATH}"
    log_info "HENSURF_OUTPUT_DIR not set, defaulting to: $FINAL_OUTPUT_DIR"
else
    FINAL_OUTPUT_DIR="$HENSURF_OUTPUT_DIR"
    log_info "Using HENSURF_OUTPUT_DIR: $FINAL_OUTPUT_DIR"
fi

# Log file path (relative to CHROMIUM_SRC_DIR)
# Ensure FINAL_OUTPUT_DIR is valid before using it in path construction
if [[ -z "$FINAL_OUTPUT_DIR" || "$FINAL_OUTPUT_DIR" == "/" ]]; then
    log_error "FINAL_OUTPUT_DIR is empty or invalid ('$FINAL_OUTPUT_DIR'). Cannot proceed."
    exit 1
fi
BUILD_LOG_FILE="$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/build.log"

# Ensure output directory exists for the log file and build artifacts
mkdir -p "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR"
# Clear previous log file or create if not exists
true >"$BUILD_LOG_FILE"

log_info "🔨 Building HenSurf Browser for $FINAL_TARGET_OS ($FINAL_TARGET_CPU)..." | tee -a "$BUILD_LOG_FILE"
log_info "   Output directory (relative to $CHROMIUM_SRC_DIR): $FINAL_OUTPUT_DIR" | tee -a "$BUILD_LOG_FILE"
log_info "   Build log: $BUILD_LOG_FILE" | tee -a "$BUILD_LOG_FILE"


# Check if Chromium source exists
if [ ! -d "$CHROMIUM_SRC_DIR" ]; then
    log_error "❌ Chromium source not found at $CHROMIUM_SRC_DIR. Please run ./scripts/fetch-chromium.sh first." | tee -a "$BUILD_LOG_FILE"
    exit 1
fi
log_success "✅ Chromium source directory found: $CHROMIUM_SRC_DIR" | tee -a "$BUILD_LOG_FILE"

# Check if essential HenSurf config (e.g. from apply-patches.sh) exists.
# This is a proxy check; args.gn will be specific to the build dir.
# We assume if scripts/apply-patches.sh was run, essential files under build/config/hensurf/ are present.
if [ ! -f "$PROJECT_ROOT/config/hensurf.gn" ]; then
    log_error "❌ HenSurf base configuration (e.g., config/hensurf.gn) not found. Please run ./scripts/apply-patches.sh or ensure config is in place." | tee -a "$BUILD_LOG_FILE"
    exit 1
fi
log_success "✅ HenSurf base configuration (config/hensurf.gn) found." | tee -a "$BUILD_LOG_FILE"

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


# Check system requirements (these checks are for the HOST machine running the build)
log_info "🔍 Checking HOST system requirements..." | tee -a "$BUILD_LOG_FILE"
# HOST_OS_TYPE is already determined above
MEMORY_GB=0
CPU_CORES=1 # Default to 1 core if detection fails

case "$HOST_OS_TYPE" in
    "mac") # Changed from "macos" to "mac" to match get_os_type
        log_info "🍏 Checking macOS host system requirements..." | tee -a "$BUILD_LOG_FILE"
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
            MEMORY_GB=0 # Default if wmic fails
            CPU_CORES=1 # Default if wmic fails
        else
            TOTAL_MEM_KB_STR=$(wmic OS get TotalVisibleMemorySize /value 2>/dev/null | tr -d '\r' | grep TotalVisibleMemorySize | cut -d'=' -f2)
            if [[ -n "$TOTAL_MEM_KB_STR" && "$TOTAL_MEM_KB_STR" =~ ^[0-9]+$ ]]; then
                MEMORY_GB=$(awk -v memkb="$TOTAL_MEM_KB_STR" 'BEGIN { printf "%.0f", memkb / 1024 / 1024 }')
            else
                log_warn "⚠️ Could not determine TotalVisibleMemorySize using wmic. Output: '$TOTAL_MEM_KB_STR'" | tee -a "$BUILD_LOG_FILE"
                MEMORY_GB=0
            fi

            CPU_CORES_STR=$(wmic cpu get NumberOfLogicalProcessors /value 2>/dev/null | tr -d '\r' | grep NumberOfLogicalProcessors | cut -d'=' -f2)
            if [[ -n "$CPU_CORES_STR" && "$CPU_CORES_STR" =~ ^[0-9]+$ ]]; then
                CPU_CORES=$CPU_CORES_STR
            else
                log_warn "⚠️ Could not determine NumberOfLogicalProcessors using wmic. Output: '$CPU_CORES_STR'" | tee -a "$BUILD_LOG_FILE"
                CPU_CORES=1
            fi
        fi
        ;;
    *)
        log_warn "⚠️ Unsupported host OS ($HOST_OS_TYPE) for detailed system checks. Proceeding with default assumptions (0GB RAM, 1 CPU core)." | tee -a "$BUILD_LOG_FILE"
        MEMORY_GB=0
        CPU_CORES=1
        ;;
esac
log_info "   Detected RAM: ${MEMORY_GB}GB, CPU Cores: $CPU_CORES" | tee -a "$BUILD_LOG_FILE"

MIN_RAM_GB=16 # Recommended RAM for building Chromium
if [ "$MEMORY_GB" -lt "$MIN_RAM_GB" ]; then
    if [ "$MEMORY_GB" -gt 0 ]; then # If memory detection worked but is low
        log_warn "⚠️  Warning: Only ${MEMORY_GB}GB RAM detected on host. ${MIN_RAM_GB}GB+ recommended for building Chromium." | tee -a "$BUILD_LOG_FILE"
    elif [[ "$HOST_OS_TYPE" == "win" || "$HOST_OS_TYPE" == "mac" || "$HOST_OS_TYPE" == "linux" ]]; then # If specific OS where detection might have failed
        log_warn "⚠️  Warning: Could not reliably determine host system RAM or it is less than ${MIN_RAM_GB}GB. ${MIN_RAM_GB}GB+ recommended for building Chromium." | tee -a "$BUILD_LOG_FILE"
    fi
    # Ask to continue only if RAM is detected as low, or if detection failed on a known OS type.
    if [[ "$MEMORY_GB" -lt "$MIN_RAM_GB" && ("$MEMORY_GB" -gt 0 || "$HOST_OS_TYPE" == "win" || "$HOST_OS_TYPE" == "mac" || "$HOST_OS_TYPE" == "linux") ]]; then
        read -r -p "Continue anyway? (y/N): " REPLY
        echo
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            log_error "User aborted due to low RAM." | tee -a "$BUILD_LOG_FILE"
            exit 1
        fi
    fi
fi

# Check available disk space on HOST
MIN_BUILD_DISK_SPACE_GB=50 # Required disk space for the build output and src
AVAILABLE_SPACE_GB=0

case "$HOST_OS_TYPE" in
    "mac"|"linux") # Corrected "macos" to "mac"
        AVAILABLE_SPACE_GB=$(df -BG "$CHROMIUM_SRC_DIR" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' | tr -d '[:space:]')
        if ! [[ "$AVAILABLE_SPACE_GB" =~ ^[0-9]+$ ]]; then AVAILABLE_SPACE_GB=0; fi # Default to 0 if parsing failed
        log_info "Disk space check ($HOST_OS_TYPE) for $CHROMIUM_SRC_DIR: ${AVAILABLE_SPACE_GB}GB available." | tee -a "$BUILD_LOG_FILE"
        ;;
    "win") # Corrected "windows" to "win"
        log_info "💻 Checking disk space on Windows in $CHROMIUM_SRC_DIR..." | tee -a "$BUILD_LOG_FILE"
        CURRENT_DRIVE_LETTER_BUILD=$(echo "$CHROMIUM_SRC_DIR" | cut -d':' -f1)
        if ! command_exists "wmic"; then
            log_warn "⚠️ 'wmic' command not found. Cannot check disk space accurately on Windows." | tee -a "$BUILD_LOG_FILE"
            AVAILABLE_SPACE_GB=0
        else
            AVAILABLE_BYTES_STR_BUILD=$(wmic logicaldisk where "DeviceID='${CURRENT_DRIVE_LETTER_BUILD}:'" get FreeSpace /value | tr -d '\r' | grep FreeSpace | cut -d'=' -f2)
            if [[ -z "$AVAILABLE_BYTES_STR_BUILD" || ! "$AVAILABLE_BYTES_STR_BUILD" =~ ^[0-9]+$ ]]; then
                 log_warn "⚠️ Could not determine free space using wmic for drive ${CURRENT_DRIVE_LETTER_BUILD}: (Output: '$AVAILABLE_BYTES_STR_BUILD')." | tee -a "$BUILD_LOG_FILE"
                 AVAILABLE_SPACE_GB=0 # Default if wmic fails
            else
                AVAILABLE_SPACE_GB=$(awk -v bytes="$AVAILABLE_BYTES_STR_BUILD" 'BEGIN { printf "%.0f", bytes / 1024 / 1024 / 1024 }')
            fi
        fi
        log_info "Drive ${CURRENT_DRIVE_LETTER_BUILD}: (for $CHROMIUM_SRC_DIR) has approximately ${AVAILABLE_SPACE_GB}GB free." | tee -a "$BUILD_LOG_FILE"
        ;;
    *)
        log_warn "⚠️ Unsupported host OS for disk space check: $HOST_OS_TYPE. Assuming ${MIN_BUILD_DISK_SPACE_GB}GB available." | tee -a "$BUILD_LOG_FILE"
        AVAILABLE_SPACE_GB=${MIN_BUILD_DISK_SPACE_GB} # Assume enough for unknown OS
        ;;
esac

if ! [[ "$AVAILABLE_SPACE_GB" =~ ^[0-9]+$ ]]; then # Sanitize if not a number
    log_warn "⚠️ Could not reliably determine available disk space for $CHROMIUM_SRC_DIR. Detected: '$AVAILABLE_SPACE_GB'. Defaulting to 0 for check." | tee -a "$BUILD_LOG_FILE"
    AVAILABLE_SPACE_GB=0 # Treat as 0 if not a number
fi

if [ "$AVAILABLE_SPACE_GB" -lt "$MIN_BUILD_DISK_SPACE_GB" ]; then
    log_warn "⚠️  Warning: Only ${AVAILABLE_SPACE_GB}GB detected as available for $CHROMIUM_SRC_DIR. Build output requires ~${MIN_BUILD_DISK_SPACE_GB}GB." | tee -a "$BUILD_LOG_FILE"
    read -r -p "Continue anyway? (y/N): " REPLY
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        log_error "User aborted due to low disk space." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
fi


# Feature flags (can be overridden by command-line args)
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
    # For faster local builds, treat_warnings_as_errors=false can be helpful
    # However, for CI or release builds, it's better to have it true.
    # This could be a command-line flag or based on build type.
    GN_ARGS_LIST+=("treat_warnings_as_errors=false")
fi

# Add core target OS and CPU to GN ARGS
# These are derived from HENSURF_TARGET_OS/CPU or native host detection
GN_ARGS_LIST+=("target_os=\"$FINAL_TARGET_OS\"")
GN_ARGS_LIST+=("target_cpu=\"$FINAL_TARGET_CPU\"")

# Add other feature flags from command line or defaults
GN_ARGS_LIST+=("hensurf_enable_bloatware=$HENSURF_ENABLE_BLOATWARE")
# Ensure important HenSurf configurations are included.
# These might be implicitly imported by `import("//build/config/hensurf/hensurf.gn")`
# in the main args.gn file of the output directory, or explicitly set here.
# For example: `import("//build/config/compiler/compiler.gni")`
#              `import("//build/config/features.gni")`
#              `is_official_build=false`
#              `is_chrome_branded=false`
#              `is_debug=false` (for release builds)
#              `dcheck_always_on=false` (for release builds)
#              `symbol_level=0` (for release builds to reduce size)
#              `blink_symbol_level=0` (for release builds)

# Construct the final GN args string
GN_ARGS_STRING_WITH_TARGETS=""
for item in "${GN_ARGS_LIST[@]}"; do
    if [ -z "$GN_ARGS_STRING_WITH_TARGETS" ]; then
        GN_ARGS_STRING_WITH_TARGETS="$item"
    else
        GN_ARGS_STRING_WITH_TARGETS="$GN_ARGS_STRING_WITH_TARGETS $item"
    fi
done

# Generate build files using FINAL_OUTPUT_DIR
# The args.gn file within $FINAL_OUTPUT_DIR should contain `import("//build/config/hensurf/hensurf.gn")`
# to load all HenSurf specific build arguments.
log_info "⚙️  Generating build files in $FINAL_OUTPUT_DIR..." | tee -a "$BUILD_LOG_FILE"
log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting gn generation..." | tee -a "$BUILD_LOG_FILE"
log_info "   GN ARGS to be applied: $GN_ARGS_STRING_WITH_TARGETS" | tee -a "$BUILD_LOG_FILE"
log_info "   Target output directory for gn: $FINAL_OUTPUT_DIR" | tee -a "$BUILD_LOG_FILE"

# The command `gn gen` will create $FINAL_OUTPUT_DIR if it doesn't exist,
# and create an args.gn file within it, then populate the build tree.
# If args.gn already exists, it will be overwritten with these command-line args.
gn gen "$FINAL_OUTPUT_DIR" --args="$GN_ARGS_STRING_WITH_TARGETS" 2>&1 | tee -a "$BUILD_LOG_FILE"
GN_GEN_STATUS=${PIPESTATUS[0]} # Get status of gn gen command

log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished gn generation." | tee -a "$BUILD_LOG_FILE"

    exit 1
fi

# Show build configuration from the generated output directory
log_info "📋 Build configuration for $FINAL_OUTPUT_DIR (from gn args $FINAL_OUTPUT_DIR --list --short):" | tee -a "$BUILD_LOG_FILE"
gn args "$FINAL_OUTPUT_DIR" --list --short 2>&1 | tee -a "$BUILD_LOG_FILE"

# Estimate build time (based on HOST capabilities)
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
log_info "   tail -f \"$BUILD_LOG_FILE\"" | tee -a "$BUILD_LOG_FILE"
log_info "" | tee -a "$BUILD_LOG_FILE"

# Build HenSurf (chrome target) using FINAL_OUTPUT_DIR
log_info "🔨 Building HenSurf browser (chrome target) in $FINAL_OUTPUT_DIR..." | tee -a "$BUILD_LOG_FILE"
log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting main browser build (autoninja -C \"$FINAL_OUTPUT_DIR\" chrome)..." | tee -a "$BUILD_LOG_FILE"
log_info "Ninja will now show detailed build progress (e.g., [X/Y] files compiled)..." | tee -a "$BUILD_LOG_FILE"

autoninja -C "$FINAL_OUTPUT_DIR" chrome 2>&1 | tee -a "$BUILD_LOG_FILE"
CHROME_BUILD_STATUS=${PIPESTATUS[0]} # Get status of autoninja command

log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished main browser build." | tee -a "$BUILD_LOG_FILE"

if command_exists "ccache"; then
    log_info "Final ccache statistics after main browser build:" | tee -a "$BUILD_LOG_FILE"
    ccache -s 2>&1 | tee -a "$BUILD_LOG_FILE"
fi

    exit 1
fi

# Build additional components
EXE_SUFFIX=""
# Use FINAL_TARGET_OS for determining suffix, not HOST_OS_TYPE
[[ "$FINAL_TARGET_OS" == "win" ]] && EXE_SUFFIX=".exe"

if [ "$BUILD_CHROMEDRIVER" = true ]; then
    log_info "🔨 Building chromedriver in $FINAL_OUTPUT_DIR..." | tee -a "$BUILD_LOG_FILE"
    if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/chromedriver$EXE_SUFFIX" ]; then
        log_info "ℹ️ chromedriver artifact already exists in $FINAL_OUTPUT_DIR. Skipping build." | tee -a "$BUILD_LOG_FILE"
    else
        log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting optional component build: chromedriver..." | tee -a "$BUILD_LOG_FILE"
        autoninja -C "$FINAL_OUTPUT_DIR" chromedriver 2>&1 | tee -a "$BUILD_LOG_FILE"
        CHROMEDRIVER_BUILD_STATUS=${PIPESTATUS[0]}
        if [[ $CHROMEDRIVER_BUILD_STATUS -ne 0 ]]; then
            log_warn "⚠️ Optional component chromedriver failed to build (exit code $CHROMEDRIVER_BUILD_STATUS) in $FINAL_OUTPUT_DIR. Continuing." | tee -a "$BUILD_LOG_FILE"
        else
            log_success "✅ Optional component chromedriver built successfully in $FINAL_OUTPUT_DIR." | tee -a "$BUILD_LOG_FILE"
        fi
        log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished optional component build: chromedriver." | tee -a "$BUILD_LOG_FILE"
    fi
else
    log_info "ℹ️ Skipping chromedriver build as per --skip-chromedriver flag." | tee -a "$BUILD_LOG_FILE"
fi

# Create application bundle for macOS (and build macOS installer)
# This section should only run if the TARGET OS is mac
if [[ "$FINAL_TARGET_OS" == "mac" ]]; then
    log_info "📦 Creating macOS application bundle in $FINAL_OUTPUT_DIR..." | tee -a "$BUILD_LOG_FILE"
    if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app" ]; then
        log_info "HenSurf.app already exists in $FINAL_OUTPUT_DIR. Removing before creating a new one." | tee -a "$BUILD_LOG_FILE"
        rm -rf "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app"
    fi

    # Determine the name of the app generated by Chromium build (usually Chromium.app or Google Chrome.app)
    # For is_chrome_branded=false (likely for HenSurf), it's Chromium.app
    EXPECTED_CHROMIUM_APP_NAME="Chromium.app"

    APP_COPIED=false
    if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/${EXPECTED_CHROMIUM_APP_NAME}" ]; then
        log_info "Found ${EXPECTED_CHROMIUM_APP_NAME} in $FINAL_OUTPUT_DIR, copying to HenSurf.app..." | tee -a "$BUILD_LOG_FILE"
        cp -R "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/${EXPECTED_CHROMIUM_APP_NAME}" "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app"
        APP_COPIED=true
    else
        # Fallback for other potential names if necessary, or error out
        log_warn "⚠️ Could not find ${EXPECTED_CHROMIUM_APP_NAME} in $FINAL_OUTPUT_DIR. Trying other common names..." | tee -a "$BUILD_LOG_FILE"
        # Example: if it could be Google Chrome.app
        # if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/Google Chrome.app" ]; then
        #    EXPECTED_CHROMIUM_APP_NAME="Google Chrome.app"
        #    cp -R "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/${EXPECTED_CHROMIUM_APP_NAME}" "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app"
        #    APP_COPIED=true
        # fi
    fi

    if [ "$APP_COPIED" = true ] && [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app" ]; then
        PLIST_BUDDY="/usr/libexec/PlistBuddy" # Standard macOS utility
        INFO_PLIST="$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app/Contents/Info.plist"

        # These values should ideally come from a centralized configuration (e.g. hensurf.gn or a version file)
        TARGET_MACOS_MIN_VERSION="10.15" # Example, ensure this matches Chromium's capabilities
        HENSURF_VERSION_STR="1.0.0" # Example
        HENSURF_BUILD_NUMBER_STR="1" # Example

        # Check if PlistBuddy is available (it should be on macOS host)
        # The actual modification of Info.plist should ideally happen on a macOS host.
        # If cross-compiling, this step might be skipped or handled differently.
        if command_exists "$PLIST_BUDDY" && [ -f "$INFO_PLIST" ]; then
            log_info "Updating Info.plist at: $INFO_PLIST" | tee -a "$BUILD_LOG_FILE"
            # Set common bundle properties
            "$PLIST_BUDDY" -c "Set :CFBundleName HenSurf" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warning: Failed to set CFBundleName" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleDisplayName HenSurf Browser" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warning: Failed to set CFBundleDisplayName" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleIdentifier com.hensurf.browser" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warning: Failed to set CFBundleIdentifier" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleShortVersionString $HENSURF_VERSION_STR" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warning: Failed to set CFBundleShortVersionString" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleVersion $HENSURF_BUILD_NUMBER_STR" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warning: Failed to set CFBundleVersion" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :LSMinimumSystemVersion $TARGET_MACOS_MIN_VERSION" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warning: Failed to set LSMinimumSystemVersion" | tee -a "$BUILD_LOG_FILE"
            # Assuming app.icns is copied from a branding package or default location
            # "$PLIST_BUDDY" -c "Set :CFBundleIconFile app.icns" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warning: Failed to set CFBundleIconFile" | tee -a "$BUILD_LOG_FILE"
            log_success "✅ HenSurf.app bundle created and Info.plist configured successfully in $FINAL_OUTPUT_DIR!" | tee -a "$BUILD_LOG_FILE"
        else
            if [[ "$HOST_OS_TYPE" == "mac" ]]; then # Only warn if on macOS host and it failed
                 log_warn "⚠️  PlistBuddy tool ($PLIST_BUDDY) not found, or Info.plist ($INFO_PLIST) missing. Cannot customize app bundle." | tee -a "$BUILD_LOG_FILE"
            else
                 log_info "ℹ️  Skipping Info.plist customization (PlistBuddy typically only available on macOS host)." | tee -a "$BUILD_LOG_FILE"
            fi
        fi
    else
        log_warn "⚠️  Could not find or copy the base app bundle '${EXPECTED_CHROMIUM_APP_NAME}' in $CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR to create HenSurf.app." | tee -a "$BUILD_LOG_FILE"
    fi

    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        if [ -f "$DMG_CHECK_FILE" ]; then
            log_info "ℹ️ macOS installer artifact ($DMG_CHECK_FILE) already exists in $FINAL_OUTPUT_DIR. Skipping build." | tee -a "$BUILD_LOG_FILE"
        else
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting optional component build: macOS mini_installer..." | tee -a "$BUILD_LOG_FILE"
            autoninja -C "$FINAL_OUTPUT_DIR" mini_installer 2>&1 | tee -a "$BUILD_LOG_FILE"
            MINI_INSTALLER_MACOS_BUILD_STATUS=${PIPESTATUS[0]}
            if [[ $MINI_INSTALLER_MACOS_BUILD_STATUS -ne 0 ]]; then
                log_warn "⚠️ Optional component macOS mini_installer failed to build (exit code $MINI_INSTALLER_MACOS_BUILD_STATUS) in $FINAL_OUTPUT_DIR. Continuing." | tee -a "$BUILD_LOG_FILE"
            else
                log_success "✅ Optional component macOS mini_installer built successfully in $FINAL_OUTPUT_DIR." | tee -a "$BUILD_LOG_FILE"
            fi
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished optional component build: macOS mini_installer." | tee -a "$BUILD_LOG_FILE"
        fi
    else
        log_info "ℹ️ Skipping macOS installer build as per --skip-mini-installer flag." | tee -a "$BUILD_LOG_FILE"
    fi

# This section is for Windows target builds
elif [[ "$FINAL_TARGET_OS" == "win" ]]; then
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        log_info "📦 Building Windows installer (mini_installer) in $FINAL_OUTPUT_DIR..." | tee -a "$BUILD_LOG_FILE"
        if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/mini_installer.exe" ] || [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/setup.exe" ]; then # Common names for installer
             log_info "ℹ️ Windows installer artifact already exists in $FINAL_OUTPUT_DIR. Skipping build." | tee -a "$BUILD_LOG_FILE"
        else
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting optional component build: Windows mini_installer..." | tee -a "$BUILD_LOG_FILE"
            autoninja -C "$FINAL_OUTPUT_DIR" mini_installer 2>&1 | tee -a "$BUILD_LOG_FILE"
            MINI_INSTALLER_WIN_BUILD_STATUS=${PIPESTATUS[0]}
            if [[ $MINI_INSTALLER_WIN_BUILD_STATUS -ne 0 ]]; then
                log_warn "⚠️ Optional component Windows mini_installer failed to build (exit code $MINI_INSTALLER_WIN_BUILD_STATUS) in $FINAL_OUTPUT_DIR. Continuing." | tee -a "$BUILD_LOG_FILE"
            else
                log_success "✅ Optional component Windows mini_installer built successfully in $FINAL_OUTPUT_DIR." | tee -a "$BUILD_LOG_FILE"
            fi
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished optional component build: Windows mini_installer." | tee -a "$BUILD_LOG_FILE"
        fi
        # Check for common installer names after build attempt
        if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/mini_installer.exe" ]; then
            log_success "✅ Windows mini_installer.exe found in $FINAL_OUTPUT_DIR." | tee -a "$BUILD_LOG_FILE"
        elif [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/setup.exe" ]; then # Chromium often names it setup.exe
            log_success "✅ Windows setup.exe found in $FINAL_OUTPUT_DIR." | tee -a "$BUILD_LOG_FILE"
        else
             # This warning is valid if the build was attempted and expected to succeed
            log_warn "⚠️  Windows installer (mini_installer.exe or setup.exe) not found in $CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR after build attempt." | tee -a "$BUILD_LOG_FILE"
        fi
    else
        log_info "ℹ️ Skipping Windows installer build as per --skip-mini-installer flag." | tee -a "$BUILD_LOG_FILE"
    fi
fi

log_info "" | tee -a "$BUILD_LOG_FILE"
log_success "🎉 HenSurf build for $FINAL_TARGET_OS-$FINAL_TARGET_CPU completed successfully!" | tee -a "$BUILD_LOG_FILE"
log_info "" | tee -a "$BUILD_LOG_FILE"
log_info "📍 Build artifacts location (relative to $CHROMIUM_SRC_DIR):" | tee -a "$BUILD_LOG_FILE"
log_info "   Main executable: $FINAL_OUTPUT_DIR/chrome${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"

if [ "$BUILD_CHROMEDRIVER" = true ] && [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/chromedriver${EXE_SUFFIX}" ]; then
    log_info "   ChromeDriver:    $FINAL_OUTPUT_DIR/chromedriver${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"
fi

# Use FINAL_TARGET_OS for these checks
if [[ "$FINAL_TARGET_OS" == "mac" ]]; then
    if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app" ]; then
        log_info "   macOS App Bundle: $FINAL_OUTPUT_DIR/HenSurf.app" | tee -a "$BUILD_LOG_FILE"
    fi
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        if [ -f "$DMG_FILE" ]; then
            log_info "   macOS Installer:  $(basename "$DMG_FILE") (in $FINAL_OUTPUT_DIR/)" | tee -a "$BUILD_LOG_FILE"
        elif [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.dmg" ]; then # Check for specific name if generic one not found
             log_info "   macOS Installer:  HenSurf.dmg (in $FINAL_OUTPUT_DIR/)" | tee -a "$BUILD_LOG_FILE"
        fi
    fi
elif [[ "$FINAL_TARGET_OS" == "win" ]]; then
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/mini_installer.exe" ]; then
            log_info "   Windows Installer: $FINAL_OUTPUT_DIR/mini_installer.exe" | tee -a "$BUILD_LOG_FILE"
        elif [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/setup.exe" ]; then # Chromium often names it setup.exe
            log_info "   Windows Installer: $FINAL_OUTPUT_DIR/setup.exe" | tee -a "$BUILD_LOG_FILE"
        else
            if [ -f "$WIN_INSTALLER_FILE" ]; then
                 log_info "   Windows Installer: $(basename "$WIN_INSTALLER_FILE") (in $FINAL_OUTPUT_DIR/)" | tee -a "$BUILD_LOG_FILE"
            fi
        fi
    fi
fi
log_info "   Build log: $BUILD_LOG_FILE" | tee -a "$BUILD_LOG_FILE"
log_info "" | tee -a "$BUILD_LOG_FILE"
log_info "🚀 To run HenSurf (from $CHROMIUM_SRC_DIR directory):" | tee -a "$BUILD_LOG_FILE"

# Use FINAL_TARGET_OS for run instructions
if [[ "$FINAL_TARGET_OS" == "mac" ]]; then
    if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app" ]; then
        log_info "   open $FINAL_OUTPUT_DIR/HenSurf.app" | tee -a "$BUILD_LOG_FILE"
    else
        log_info "   ./$FINAL_OUTPUT_DIR/chrome  (App bundle creation failed or was skipped)" | tee -a "$BUILD_LOG_FILE"
    fi
elif [[ "$FINAL_TARGET_OS" == "win" ]]; then
    log_info "   ./$FINAL_OUTPUT_DIR/chrome${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"
else # Assuming Linux or other POSIX-like
    log_info "   ./$FINAL_OUTPUT_DIR/chrome" | tee -a "$BUILD_LOG_FILE"
fi
log_info "" | tee -a "$BUILD_LOG_FILE"
log_info "📋 HenSurf features:" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ No AI-powered suggestions" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ No Google services integration" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ DuckDuckGo as default search" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ Enhanced privacy settings" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ Minimal telemetry" | tee -a "$BUILD_LOG_FILE"
log_info "   ✅ Clean, bloatware-free interface" | tee -a "$BUILD_LOG_FILE"