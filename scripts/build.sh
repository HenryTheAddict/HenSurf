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
CHROMIUM_SRC_DIR="$PROJECT_ROOT/src/chromium"

# --- Global Variables ---
# These variables are used throughout the script. Many are set by `setup_environment_variables` or `check_system_requirements`.

FINAL_TARGET_OS=""            # Target OS for the build (e.g., "linux", "mac", "win"). Set by setup_environment_variables.
FINAL_TARGET_CPU=""           # Target CPU architecture (e.g., "x64", "arm64"). Set by setup_environment_variables.
FINAL_OUTPUT_DIR=""           # Relative path from $CHROMIUM_SRC_DIR for build artifacts (e.g., "out/HenSurf-linux-x64"). Set by setup_environment_variables.
BUILD_LOG_FILE=""             # Full path to the build log file. Set by setup_environment_variables.
HOST_OS_TYPE=""               # OS type of the machine running the script (e.g., "ubuntu", "macos", specific distro if Linux). Set by setup_environment_variables.
MEMORY_GB=0                   # Detected host memory in GB. Set by check_system_requirements.
CPU_CORES=1                   # Detected host CPU cores. Set by check_system_requirements.
GN_ARGS_STRING_WITH_TARGETS="" # String containing all GN arguments. Set by configure_gn_arguments.

# --- Feature Flags ---
# These can be overridden by command-line arguments parsed in `configure_gn_arguments`.
HENSURF_ENABLE_BLOATWARE=0 # Default to disabled. Controls 'hensurf_enable_bloatware' GN arg.
BUILD_CHROMEDRIVER=true    # Whether to build chromedriver.
BUILD_MINI_INSTALLER=true  # Whether to build mini_installer.
DEV_FAST_MODE=false        # Enables developer-centric fast build options (e.g., component build, no warnings as errors).


# --- Function Definitions ---

# Sets up critical environment variables:
# - FINAL_TARGET_OS: Target OS for the build (e.g., "mac", "linux", "win" for GN).
# - FINAL_TARGET_CPU: Target CPU architecture (e.g., "x64", "arm64").
# - FINAL_OUTPUT_DIR: Output directory for build artifacts.
# - BUILD_LOG_FILE: Path to the build log.
# - HOST_OS_TYPE: OS of the machine running the script (used for host-specific checks).
# Reads HENSURF_TARGET_OS, HENSURF_TARGET_CPU, HENSURF_OUTPUT_DIR environment variables if set,
# otherwise determines sensible defaults based on the host system.
# Globals modified: FINAL_TARGET_OS, FINAL_TARGET_CPU, FINAL_OUTPUT_DIR, BUILD_LOG_FILE, HOST_OS_TYPE.
setup_environment_variables() {
    log_info "--- Setting up Environment Variables ---"
    # Get host OS using utils.sh for host-side checks (e.g., PlistBuddy availability).
    # get_os_distro provides specific distro, _get_os_type_internal provides general type.
    HOST_OS_TYPE=$(get_os_distro) # From utils.sh; e.g., "ubuntu", "fedora", "macos", "windows"
    local native_os_for_gn
    native_os_for_gn=$(_get_os_type_internal) # From utils.sh; for GN, we need "mac", "linux", "win"

    # Determine FINAL_TARGET_OS (for GN's target_os)
    if [ -z "$HENSURF_TARGET_OS" ]; then
        FINAL_TARGET_OS="$native_os_for_gn"
        log_info "HENSURF_TARGET_OS not set by environment, defaulting to native OS for GN: '$FINAL_TARGET_OS'"
    else
        FINAL_TARGET_OS="$HENSURF_TARGET_OS"
        log_info "Using HENSURF_TARGET_OS from environment: '$FINAL_TARGET_OS'"
    fi

    # Determine FINAL_TARGET_CPU (for GN's target_cpu)
    if [ -z "$HENSURF_TARGET_CPU" ]; then
        local NATIVE_CPU_ARCH=""
        # Use the GN-compatible native OS type for CPU detection logic
        case "$native_os_for_gn" in
            "macos")
                _UNAME_M_OUTPUT=$(uname -m)
                if [[ "$_UNAME_M_OUTPUT" == "x86_64" ]]; then NATIVE_CPU_ARCH="x64";
                elif [[ "$_UNAME_M_OUTPUT" == "arm64" ]]; then NATIVE_CPU_ARCH="arm64";
                else log_warn "Unknown macOS arch via uname -m: '$_UNAME_M_OUTPUT'. Defaulting to x64."; NATIVE_CPU_ARCH="x64"; fi
                ;;
            "linux")
                _UNAME_M_OUTPUT=$(uname -m)
                if [[ "$_UNAME_M_OUTPUT" == "x86_64" ]]; then NATIVE_CPU_ARCH="x64";
                elif [[ "$_UNAME_M_OUTPUT" == "aarch64" ]]; then NATIVE_CPU_ARCH="arm64";
                elif [[ "$_UNAME_M_OUTPUT" == "armv7l" ]]; then NATIVE_CPU_ARCH="arm"; # 32-bit ARM
                else log_warn "Unknown Linux arch via uname -m: '$_UNAME_M_OUTPUT'. Defaulting to x64."; NATIVE_CPU_ARCH="x64"; fi
                ;;
            "windows")
                if [[ -n "$PROCESSOR_ARCHITECTURE" ]]; then # Primarily for CMD/PowerShell
                    if [[ "$PROCESSOR_ARCHITECTURE" == "AMD64" ]] || [[ "$PROCESSOR_ARCHITECTURE" == "EM64T" ]]; then NATIVE_CPU_ARCH="x64";
                    elif [[ "$PROCESSOR_ARCHITECTURE" == "ARM64" ]]; then NATIVE_CPU_ARCH="arm64";
                    else log_warn "Unknown Windows arch (PROCESSOR_ARCHITECTURE): '$PROCESSOR_ARCHITECTURE'. Defaulting to x64."; NATIVE_CPU_ARCH="x64"; fi
                elif [[ "$(uname -m)" == "x86_64" ]]; then # Fallback for Git Bash/MSYS
                    NATIVE_CPU_ARCH="x64"
                elif [[ "$(uname -m)" == "aarch64" ]]; then # Fallback for Git Bash/MSYS ARM
                     NATIVE_CPU_ARCH="arm64"
                else
                    log_warn "Unknown Windows arch (uname -m): '$(uname -m)'. Defaulting to x64."; NATIVE_CPU_ARCH="x64";
                fi
                ;;
            *)
                log_warn "Unsupported host OS '$native_os_for_gn' for CPU detection. Defaulting target CPU to x64."
                NATIVE_CPU_ARCH="x64"
                ;;
        esac
        FINAL_TARGET_CPU="$NATIVE_CPU_ARCH"
        log_info "HENSURF_TARGET_CPU not set by environment, defaulting to detected native CPU: '$FINAL_TARGET_CPU' (host OS for detection: '$native_os_for_gn')"
    else
        FINAL_TARGET_CPU="$HENSURF_TARGET_CPU"
        log_info "Using HENSURF_TARGET_CPU from environment: '$FINAL_TARGET_CPU'"
    fi

    # Determine FINAL_OUTPUT_DIR
    if [ -z "$HENSURF_OUTPUT_DIR" ]; then
        # Sanitize OS/CPU names for path, default to "unknown" if empty
        local path_os=${FINAL_TARGET_OS:-"unknownOS"}
        local path_cpu=${FINAL_TARGET_CPU:-"unknownCPU"}
        FINAL_OUTPUT_DIR="out/HenSurf-${path_os}-${path_cpu}"
        log_info "HENSURF_OUTPUT_DIR not set by environment, defaulting to: '$FINAL_OUTPUT_DIR'"
    else
        FINAL_OUTPUT_DIR="$HENSURF_OUTPUT_DIR"
        log_info "Using HENSURF_OUTPUT_DIR from environment: '$FINAL_OUTPUT_DIR'"
    fi

    # Validate FINAL_OUTPUT_DIR and set BUILD_LOG_FILE
    if [[ -z "$FINAL_OUTPUT_DIR" || "$FINAL_OUTPUT_DIR" == "/" ]]; then
        log_error "FINAL_OUTPUT_DIR is empty or invalid ('$FINAL_OUTPUT_DIR'). Cannot proceed."
        exit 1
    fi
    # Ensure BUILD_LOG_FILE is an absolute path or relative to a known location if needed.
    # Here, it's relative to CHROMIUM_SRC_DIR.
    BUILD_LOG_FILE="$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/build.log"

    # Ensure output directory for the log file exists; tee will also create the log file.
    mkdir -p "$(dirname "$BUILD_LOG_FILE")"
    # Clear previous log file or create if not exists, then append to it.
    # Using tee ensures messages go to both stdout and the log file.
    true >"$BUILD_LOG_FILE"

    log_info "🔨 Building HenSurf Browser for $FINAL_TARGET_OS ($FINAL_TARGET_CPU)..." | tee -a "$BUILD_LOG_FILE"
    log_info "   Output directory (relative to $CHROMIUM_SRC_DIR e.g., src/chromium/out/HenSurf-linux-x64): $FINAL_OUTPUT_DIR" | tee -a "$BUILD_LOG_FILE"
    log_info "   Build log: $BUILD_LOG_FILE" | tee -a "$BUILD_LOG_FILE"
}

# Checks host system requirements: OS, memory, CPU cores, and disk space.
# Warns prominently if requirements are below recommended values and may prompt the user to continue.
# Globals modified: MEMORY_GB, CPU_CORES.
# Globals used: HOST_OS_TYPE (set by setup_environment_variables), CHROMIUM_SRC_DIR, BUILD_LOG_FILE.
check_system_requirements() {
    log_info "--- Checking Host System Requirements ---"
    # HOST_OS_TYPE (specific distro) is already set. For broad checks, use _get_os_type_internal.
    local current_host_os_category
    current_host_os_category=$(_get_os_type_internal) # e.g., "macos", "linux", "windows"

    MEMORY_GB=0 # Will be updated by OS-specific checks
    CPU_CORES=1 # Default to 1 core if detection fails

    case "$current_host_os_category" in
        "macos")
            log_info "🍏 Checking macOS host system requirements..." | tee -a "$BUILD_LOG_FILE"
            MEMORY_GB=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024/1024)}' || echo 0)
            CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
            ;;
        "linux")
            log_info "🐧 Checking Linux system requirements..." | tee -a "$BUILD_LOG_FILE"
            if [ -f /proc/meminfo ]; then
                MEMORY_GB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
            else
                local MEMORY_KB
                local MEMORY_KB
                MEMORY_KB=$(free | grep Mem: | awk '{print $2}')
                if [[ "$MEMORY_KB" =~ ^[0-9]+$ ]]; then
                    MEMORY_GB=$(awk -v memkb="$MEMORY_KB" 'BEGIN { printf "%.0f", memkb / 1024 / 1024 }')
                else
                    log_warn "⚠️ Could not determine system memory from /proc/meminfo or free." | tee -a "$BUILD_LOG_FILE"
                fi
            fi
            if command_exists "nproc"; then CPU_CORES=$(nproc);
            else CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1); log_warn "⚠️ nproc not found, using /proc/cpuinfo or defaulting to $CPU_CORES." | tee -a "$BUILD_LOG_FILE"; fi
            ;;
        "windows")
            log_info "💻 Checking Windows system requirements..." | tee -a "$BUILD_LOG_FILE"
            if ! command_exists "wmic"; then
                log_warn "⚠️ 'wmic' command not found. Cannot check system requirements accurately." | tee -a "$BUILD_LOG_FILE"
            else
                local TOTAL_MEM_KB_STR
                local TOTAL_MEM_KB_STR
                TOTAL_MEM_KB_STR=$(wmic OS get TotalVisibleMemorySize /value 2>/dev/null | tr -d '\r' | grep TotalVisibleMemorySize | cut -d'=' -f2)
                if [[ -n "$TOTAL_MEM_KB_STR" && "$TOTAL_MEM_KB_STR" =~ ^[0-9]+$ ]]; then
                    MEMORY_GB=$(awk -v memkb="$TOTAL_MEM_KB_STR" 'BEGIN { printf "%.0f", memkb / 1024 / 1024 }')
                else
                    log_warn "⚠️ Could not determine TotalVisibleMemorySize via wmic. Output: '$TOTAL_MEM_KB_STR'" | tee -a "$BUILD_LOG_FILE"; MEMORY_GB=0;
                fi
                local CPU_CORES_STR
                CPU_CORES_STR=$(wmic cpu get NumberOfLogicalProcessors /value 2>/dev/null | tr -d '\r' | grep NumberOfLogicalProcessors | cut -d'=' -f2)
                if [[ -n "$CPU_CORES_STR" && "$CPU_CORES_STR" =~ ^[0-9]+$ ]]; then CPU_CORES=$CPU_CORES_STR;
                else log_warn "⚠️ Could not determine NumberOfLogicalProcessors via wmic. Output: '$CPU_CORES_STR'" | tee -a "$BUILD_LOG_FILE"; CPU_CORES=1; fi
            fi
            ;;
        *)
            # Use HOST_OS_TYPE (specific distro) in this warning for better user info
            log_warn "⚠️ Unsupported host OS ('$current_host_os_category' / specific: '$HOST_OS_TYPE') for detailed system checks. Defaults: 0GB RAM, 1 CPU core." | tee -a "$BUILD_LOG_FILE"
            MEMORY_GB=0; CPU_CORES=1;
            ;;
    esac
    log_info "   Detected RAM: ${MEMORY_GB}GB, CPU Cores: $CPU_CORES" | tee -a "$BUILD_LOG_FILE"

    local MIN_RAM_GB=16 # Recommended RAM for Chromium build
    if ! [[ "$MEMORY_GB" =~ ^[0-9]+$ && "$MEMORY_GB" -ge "$MIN_RAM_GB" ]]; then # Check if less or not a number
        if [[ "$MEMORY_GB" =~ ^[0-9]+$ && "$MEMORY_GB" -gt 0 ]]; then # Detected, but low
            log_warn "🔥🔥🔥 LOW RAM WARNING: Only ${MEMORY_GB}GB RAM detected. ${MIN_RAM_GB}GB+ recommended for building Chromium. 🔥🔥🔥" | tee -a "$BUILD_LOG_FILE"
        else # Detection failed or was 0
             log_warn "🔥🔥🔥 RAM WARNING: Could not reliably determine host system RAM or it is less than ${MIN_RAM_GB}GB. ${MIN_RAM_GB}GB+ recommended. 🔥🔥🔥" | tee -a "$BUILD_LOG_FILE"
        fi
        # Ask to continue only if RAM is detected as low, or if detection failed on a known OS type.
        if [[ "$MEMORY_GB" -lt "$MIN_RAM_GB" && ("$MEMORY_GB" -gt 0 || "$current_host_os_category" == "windows" || "$current_host_os_category" == "macos" || "$current_host_os_category" == "linux") ]]; then
            read -r -p "Build might be very slow or fail. Continue anyway? (y/N): " REPLY; echo
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then log_error "User aborted due to low RAM." | tee -a "$BUILD_LOG_FILE"; exit 1; fi
        fi
    fi

    local MIN_BUILD_DISK_SPACE_GB=50 # Recommended disk space
    local AVAILABLE_SPACE_GB=0
    case "$current_host_os_category" in
        "macos"|"linux")
            # Get available space in GB for the directory containing CHROMIUM_SRC_DIR
            AVAILABLE_SPACE_GB=$(df -BG "$CHROMIUM_SRC_DIR" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' | tr -d '[:space:]' || echo 0)
            if ! [[ "$AVAILABLE_SPACE_GB" =~ ^[0-9]+$ ]]; then AVAILABLE_SPACE_GB=0; fi # Default to 0 if parsing failed
            log_info "Disk space check ($current_host_os_category) for $CHROMIUM_SRC_DIR: ${AVAILABLE_SPACE_GB}GB available." | tee -a "$BUILD_LOG_FILE"
            ;;
        "windows")
            log_info "💻 Checking disk space on Windows in $CHROMIUM_SRC_DIR..." | tee -a "$BUILD_LOG_FILE"
            local CURRENT_DRIVE_LETTER_BUILD
            CURRENT_DRIVE_LETTER_BUILD=$(echo "$CHROMIUM_SRC_DIR" | cut -d':' -f1)
            if ! command_exists "wmic"; then
                log_warn "⚠️ 'wmic' command not found. Cannot check disk space accurately." | tee -a "$BUILD_LOG_FILE"
            else
                local AVAILABLE_BYTES_STR_BUILD
                AVAILABLE_BYTES_STR_BUILD=$(wmic logicaldisk where "DeviceID='${CURRENT_DRIVE_LETTER_BUILD}:'" get FreeSpace /value | tr -d '\r' | grep FreeSpace | cut -d'=' -f2)
                if [[ -z "$AVAILABLE_BYTES_STR_BUILD" || ! "$AVAILABLE_BYTES_STR_BUILD" =~ ^[0-9]+$ ]]; then
                     log_warn "⚠️ Could not determine free space via wmic for drive ${CURRENT_DRIVE_LETTER_BUILD}: (Output: '$AVAILABLE_BYTES_STR_BUILD')." | tee -a "$BUILD_LOG_FILE"; AVAILABLE_SPACE_GB=0;
                else
                    AVAILABLE_SPACE_GB=$(awk -v bytes="$AVAILABLE_BYTES_STR_BUILD" 'BEGIN { printf "%.0f", bytes / 1024 / 1024 / 1024 }')
                fi
            fi
            log_info "Drive ${CURRENT_DRIVE_LETTER_BUILD}: (for $CHROMIUM_SRC_DIR) has approx ${AVAILABLE_SPACE_GB}GB free." | tee -a "$BUILD_LOG_FILE"
            ;;
        *)
            log_warn "⚠️ Unsupported host OS ($current_host_os_category) for disk space check. Assuming ${MIN_BUILD_DISK_SPACE_GB}GB." | tee -a "$BUILD_LOG_FILE"; AVAILABLE_SPACE_GB=${MIN_BUILD_DISK_SPACE_GB};
            ;;
    esac

    if ! [[ "$AVAILABLE_SPACE_GB" =~ ^[0-9]+$ ]]; then
        log_warn "⚠️ Could not reliably determine disk space for $CHROMIUM_SRC_DIR. Detected: '$AVAILABLE_SPACE_GB'. Defaulting to 0." | tee -a "$BUILD_LOG_FILE"; AVAILABLE_SPACE_GB=0;
    fi

    if [ "$AVAILABLE_SPACE_GB" -lt "$MIN_BUILD_DISK_SPACE_GB" ]; then
        log_warn "🔥🔥🔥 LOW DISK SPACE WARNING: Only ${AVAILABLE_SPACE_GB}GB detected for $CHROMIUM_SRC_DIR. Build needs ~${MIN_BUILD_DISK_SPACE_GB}GB. 🔥🔥🔥" | tee -a "$BUILD_LOG_FILE"
        read -r -p "Continue anyway? (y/N): " REPLY; echo
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then log_error "User aborted due to low disk space." | tee -a "$BUILD_LOG_FILE"; exit 1; fi
    fi
}

# Configures GN arguments based on command-line flags and defaults.
# Populates GN_ARGS_STRING_WITH_TARGETS (global variable).
# Modifies global feature flags: HENSURF_ENABLE_BLOATWARE, BUILD_CHROMEDRIVER, BUILD_MINI_INSTALLER, DEV_FAST_MODE.
# Arguments:
#   $@ - Command line arguments passed to the main script. These are parsed here to set feature flags.
configure_gn_arguments() {
    log_info "--- Configuring GN Arguments ---"
    # Parse command-line arguments to override default feature flags
    # These globals are modified: HENSURF_ENABLE_BLOATWARE, BUILD_CHROMEDRIVER, BUILD_MINI_INSTALLER, DEV_FAST_MODE
    # Using a temporary array for arguments to avoid issues with `shift` in the loop if called multiple times or with `getopts` later.
    local args_copy=("$@")
    local i=0
    while [ $i -lt ${#args_copy[@]} ]; do
        local key="${args_copy[$i]}"
        case $key in
            --enable-bloatware) HENSURF_ENABLE_BLOATWARE=1 ;;
            --no-enable-bloatware) HENSURF_ENABLE_BLOATWARE=0 ;;
            --skip-chromedriver) BUILD_CHROMEDRIVER=false ;;
            --skip-mini-installer) BUILD_MINI_INSTALLER=false ;;
            --dev-fast) DEV_FAST_MODE=true ;;
            # *) # Do not error on unknown options, allow them to be passed to other tools if necessary
        esac
        i=$((i + 1))
    done

    local GN_ARGS_LIST=() # Local array to build up arguments

    # Developer Fast Mode options
    if [ "$DEV_FAST_MODE" = true ]; then
        log_info "🚀 Developer Fast Mode enabled: is_component_build=true, treat_warnings_as_errors=false" | tee -a "$BUILD_LOG_FILE"
        GN_ARGS_LIST+=("is_component_build=true")
        GN_ARGS_LIST+=("treat_warnings_as_errors=false") # Faster local iteration
    else
        # Default release-like flags (can be overridden by hensurf.gn if needed)
        GN_ARGS_LIST+=("is_component_build=false")
        GN_ARGS_LIST+=("treat_warnings_as_errors=true")
        GN_ARGS_LIST+=("is_debug=false")
        GN_ARGS_LIST+=("dcheck_always_on=false") # dcheck_always_on=true is for debug/dev
        GN_ARGS_LIST+=("symbol_level=0") # Minimal symbols for smaller release builds
        GN_ARGS_LIST+=("blink_symbol_level=0")
    fi

    # Core target settings (already determined in setup_environment_variables)
    GN_ARGS_LIST+=("target_os=\"$FINAL_TARGET_OS\"")
    GN_ARGS_LIST+=("target_cpu=\"$FINAL_TARGET_CPU\"")

    # HenSurf specific features
    GN_ARGS_LIST+=("hensurf_enable_bloatware=$HENSURF_ENABLE_BLOATWARE")
    log_info "HenSurf Bloatware feature set to: $HENSURF_ENABLE_BLOATWARE" | tee -a "$BUILD_LOG_FILE"

    # Other common Chromium build flags (add more as needed, or ensure they are in hensurf.gn)
    GN_ARGS_LIST+=("is_official_build=false") # Typically false for custom builds
    GN_ARGS_LIST+=("is_chrome_branded=false")  # Crucial for removing Google branding elements
    # GN_ARGS_LIST+=("enable_nacl=false") # Example: Disable Native Client
    # GN_ARGS_LIST+=("proprietary_codecs=true") # Example: Include proprietary codecs if licensing allows
    # GN_ARGS_LIST+=("ffmpeg_branding=\"Chromium\"") # Or "Chrome" if proprietary_codecs=true

    # Construct the final GN args string for use in `gn gen`
    # This is a global variable, so it doesn't need to be returned.
    GN_ARGS_STRING_WITH_TARGETS=""
    for item in "${GN_ARGS_LIST[@]}"; do
        if [ -z "$GN_ARGS_STRING_WITH_TARGETS" ]; then
            GN_ARGS_STRING_WITH_TARGETS="$item"
        else
            # Append with a space separator
            GN_ARGS_STRING_WITH_TARGETS="$GN_ARGS_STRING_WITH_TARGETS $item"
        fi
    done
    log_info "Final GN ARGS to be applied: $GN_ARGS_STRING_WITH_TARGETS" | tee -a "$BUILD_LOG_FILE"
}

# Runs `gn gen` to generate build files using the configured arguments.
# After generation, it lists the applied build configuration.
# Uses global variables: FINAL_OUTPUT_DIR, GN_ARGS_STRING_WITH_TARGETS, BUILD_LOG_FILE.
# Exits script on `gn gen` failure.
run_gn_gen() {
    log_info "--- Running GN Gen ---"
    log_info "⚙️  Generating build files in $FINAL_OUTPUT_DIR..." | tee -a "$BUILD_LOG_FILE"
    log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting gn generation..." | tee -a "$BUILD_LOG_FILE"
    log_info "   GN ARGS to be applied: $GN_ARGS_STRING_WITH_TARGETS" | tee -a "$BUILD_LOG_FILE"
    log_info "   Target output directory for gn: $FINAL_OUTPUT_DIR" | tee -a "$BUILD_LOG_FILE"

    gn gen "$FINAL_OUTPUT_DIR" --args="$GN_ARGS_STRING_WITH_TARGETS" 2>&1 | tee -a "$BUILD_LOG_FILE"
    local GN_GEN_STATUS=${PIPESTATUS[0]}
    if [ "$GN_GEN_STATUS" -ne 0 ]; then
        log_error "❌ gn gen failed with status $GN_GEN_STATUS." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
    log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished gn generation." | tee -a "$BUILD_LOG_FILE"

    log_info "📋 Build configuration for $FINAL_OUTPUT_DIR (from gn args $FINAL_OUTPUT_DIR --list --short):" | tee -a "$BUILD_LOG_FILE"
    gn args "$FINAL_OUTPUT_DIR" --list --short 2>&1 | tee -a "$BUILD_LOG_FILE"
}

# Executes the main build process using autoninja.
# Logs ccache statistics before and after the build.
execute_build() {
    log_info "--- Executing Build ---"
    local BASE_BUILD_HOURS=8
    if [[ -n "$HENSURF_BASE_BUILD_HOURS" && "$HENSURF_BASE_BUILD_HOURS" =~ ^[0-9]+([.][0-9]+)?$ && $(echo "$HENSURF_BASE_BUILD_HOURS > 0" | bc -l) -eq 1 ]]; then
        BASE_BUILD_HOURS=$HENSURF_BASE_BUILD_HOURS
        log_info "ℹ️ Using HENSURF_BASE_BUILD_HOURS=$HENSURF_BASE_BUILD_HOURS for estimation." | tee -a "$BUILD_LOG_FILE"
    fi

    local ESTIMATED_HOURS
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

    if command_exists "ccache"; then
        log_info "Initial ccache statistics before main build:" | tee -a "$BUILD_LOG_FILE"
        ccache -s 2>&1 | tee -a "$BUILD_LOG_FILE"
    fi

    log_info "🔨 Building HenSurf browser (chrome target) in $FINAL_OUTPUT_DIR..." | tee -a "$BUILD_LOG_FILE"
    log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting main browser build (autoninja -C \"$FINAL_OUTPUT_DIR\" chrome)..." | tee -a "$BUILD_LOG_FILE"
    log_info "Ninja will now show detailed build progress (e.g., [X/Y] files compiled)..." | tee -a "$BUILD_LOG_FILE"

    autoninja -C "$FINAL_OUTPUT_DIR" chrome 2>&1 | tee -a "$BUILD_LOG_FILE"
    local CHROME_BUILD_STATUS=${PIPESTATUS[0]}
    if [ "$CHROME_BUILD_STATUS" -ne 0 ]; then
        log_error "❌ autoninja chrome build failed with status $CHROME_BUILD_STATUS." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
    log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished main browser build." | tee -a "$BUILD_LOG_FILE"

    if command_exists "ccache"; then
        log_info "Final ccache statistics after main browser build:" | tee -a "$BUILD_LOG_FILE"
        ccache -s 2>&1 | tee -a "$BUILD_LOG_FILE"
    fi
}


# --- Main Script Logic ---

main() {
    setup_environment_variables "$@" # Pass all script args for potential use

    # Check if Chromium source exists
    if [ ! -d "$CHROMIUM_SRC_DIR" ]; then
        log_error "❌ Chromium source not found at $CHROMIUM_SRC_DIR. Please run ./scripts/fetch-chromium.sh first." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
    log_success "✅ Chromium source directory found: $CHROMIUM_SRC_DIR" | tee -a "$BUILD_LOG_FILE"

    # Check if essential HenSurf config exists
    if [ ! -f "$PROJECT_ROOT/src/hensurf/config/hensurf.gn" ]; then
        log_error "❌ HenSurf base configuration (src/hensurf/config/hensurf.gn) not found. Please run ./scripts/apply-patches.sh or ensure config is in place." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
    log_success "✅ HenSurf base configuration (src/hensurf/config/hensurf.gn) found." | tee -a "$BUILD_LOG_FILE"

    # Depot Tools Setup
    local DEPOT_TOOLS_DIR
    if ! DEPOT_TOOLS_DIR=$(find_depot_tools_path "$PROJECT_ROOT"); then
        # Error messages are handled by find_depot_tools_path
        log_error "   Build script cannot proceed without depot_tools." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
    # add_depot_tools_to_path also logs success/failure and the path being added
    if ! add_depot_tools_to_path "$DEPOT_TOOLS_DIR"; then
        # Error message already logged by add_depot_tools_to_path
        log_error "Failed to add depot_tools to PATH. Exiting." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi

    # Check for essential commands from depot_tools
    if ! command_exists "gn"; then
        log_error "Critical: 'gn' command not found. 'gn' is required to configure the build." | tee -a "$BUILD_LOG_FILE"
        log_error "Ensure depot_tools is correctly installed and in PATH." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
    if ! command_exists "autoninja"; then
        log_error "Critical: 'autoninja' command not found. 'autoninja' is required to build the project." | tee -a "$BUILD_LOG_FILE"
        log_error "Ensure depot_tools is correctly installed and in PATH." | tee -a "$BUILD_LOG_FILE"
        exit 1
    fi
    log_success "✅ 'gn' and 'autoninja' commands found." | tee -a "$BUILD_LOG_FILE"

    # Configure ccache
    export CCACHE_CPP2=true
    export CCACHE_SLOPPINESS="time_macros"
    if [ -n "$CCACHE_DIR" ]; then log_info "ℹ️ Using custom CCACHE_DIR: $CCACHE_DIR" | tee -a "$BUILD_LOG_FILE"; fi
    if ! command_exists "ccache"; then
        log_warn "⚠️ ccache command not found. Build will proceed without ccache." | tee -a "$BUILD_LOG_FILE"
    else
        log_success "✅ ccache found: $(command -v ccache)" | tee -a "$BUILD_LOG_FILE"
    fi

    # Navigate to the chromium source directory
    safe_cd "$CHROMIUM_SRC_DIR" # Using safe_cd from utils.sh
    # log_info is already part of safe_cd on success

    check_system_requirements # Uses and sets MEMORY_GB, CPU_CORES

    # Pass all script arguments to configure_gn_arguments
    configure_gn_arguments "$@"

    run_gn_gen

    execute_build
    build_additional_components
    package_macos_bundle # This function will internally check if it needs to run
    summarize_build_artifacts
}

# Builds additional components like chromedriver and mini_installer based on flags and target OS.
build_additional_components() {
    log_info "--- Building Additional Components ---"
    local EXE_SUFFIX=""
    [[ "$FINAL_TARGET_OS" == "win" ]] && EXE_SUFFIX=".exe"

    # Build chromedriver
    if [ "$BUILD_CHROMEDRIVER" = true ]; then
        log_info "🔨 Building chromedriver in $FINAL_OUTPUT_DIR..." | tee -a "$BUILD_LOG_FILE"
        if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/chromedriver$EXE_SUFFIX" ]; then
            log_info "ℹ️ chromedriver artifact already exists. Skipping build." | tee -a "$BUILD_LOG_FILE"
        else
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting chromedriver build..." | tee -a "$BUILD_LOG_FILE"
            autoninja -C "$FINAL_OUTPUT_DIR" chromedriver 2>&1 | tee -a "$BUILD_LOG_FILE"
            local STATUS=${PIPESTATUS[0]}
            if [[ $STATUS -ne 0 ]]; then
                log_warn "⚠️ chromedriver failed to build (code $STATUS). Continuing." | tee -a "$BUILD_LOG_FILE"
            else
                log_success "✅ chromedriver built successfully." | tee -a "$BUILD_LOG_FILE"
            fi
            log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished chromedriver build." | tee -a "$BUILD_LOG_FILE"
        fi
    else
        log_info "ℹ️ Skipping chromedriver build (--skip-chromedriver)." | tee -a "$BUILD_LOG_FILE"
    fi

    # Build mini_installer (OS-specific handling)
    if [ "$BUILD_MINI_INSTALLER" = true ]; then
        if [[ "$FINAL_TARGET_OS" == "mac" ]]; then
            log_info "📦 Building macOS mini_installer..." | tee -a "$BUILD_LOG_FILE"
            if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.dmg" ] || [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/mini_installer.dmg" ]; then
                log_info "ℹ️ macOS installer (HenSurf.dmg or mini_installer.dmg) already exists. Skipping." | tee -a "$BUILD_LOG_FILE"
            else
                log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting macOS mini_installer build..." | tee -a "$BUILD_LOG_FILE"
                autoninja -C "$FINAL_OUTPUT_DIR" mini_installer 2>&1 | tee -a "$BUILD_LOG_FILE"
                local STATUS=${PIPESTATUS[0]}
                if [[ $STATUS -ne 0 ]]; then
                    log_warn "⚠️ macOS mini_installer failed (code $STATUS). Continuing." | tee -a "$BUILD_LOG_FILE"
                else
                    log_success "✅ macOS mini_installer built successfully." | tee -a "$BUILD_LOG_FILE"
                fi
                log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished macOS mini_installer build." | tee -a "$BUILD_LOG_FILE"
            fi
        elif [[ "$FINAL_TARGET_OS" == "win" ]]; then
            log_info "📦 Building Windows mini_installer..." | tee -a "$BUILD_LOG_FILE"
            if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/mini_installer.exe" ] || [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/setup.exe" ]; then
                 log_info "ℹ️ Windows installer (mini_installer.exe or setup.exe) already exists. Skipping." | tee -a "$BUILD_LOG_FILE"
            else
                log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Windows mini_installer build..." | tee -a "$BUILD_LOG_FILE"
                autoninja -C "$FINAL_OUTPUT_DIR" mini_installer 2>&1 | tee -a "$BUILD_LOG_FILE"
                local STATUS=${PIPESTATUS[0]}
                if [[ $STATUS -ne 0 ]]; then
                    log_warn "⚠️ Windows mini_installer failed (code $STATUS). Continuing." | tee -a "$BUILD_LOG_FILE"
                else
                    log_success "✅ Windows mini_installer built successfully." | tee -a "$BUILD_LOG_FILE"
                fi
                log_info "[$(date '+%Y-%m-%d %H:%M:%S')] Finished Windows mini_installer build." | tee -a "$BUILD_LOG_FILE"
            fi
            # Verify installer presence after attempt
            if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/mini_installer.exe" ]; then
                log_success "✅ Windows mini_installer.exe found." | tee -a "$BUILD_LOG_FILE"
            elif [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/setup.exe" ]; then
                log_success "✅ Windows setup.exe found." | tee -a "$BUILD_LOG_FILE"
            else
                log_warn "⚠️ Windows installer not found after build attempt." | tee -a "$BUILD_LOG_FILE"
            fi
        else
            log_info "ℹ️ No mini_installer build step for $FINAL_TARGET_OS." | tee -a "$BUILD_LOG_FILE"
        fi
    else
        log_info "ℹ️ Skipping mini_installer build (--skip-mini-installer)." | tee -a "$BUILD_LOG_FILE"
    fi
}

# Creates the .app bundle for macOS, including Info.plist modifications.
# This function should only be called when FINAL_TARGET_OS is "mac".
package_macos_bundle() {
    if [[ "$FINAL_TARGET_OS" != "mac" ]]; then
        log_info "ℹ️ Skipping macOS bundle creation (target OS is $FINAL_TARGET_OS, not mac)."
        return 0
    fi

    log_info "--- Packaging macOS Application Bundle ---"
    if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app" ]; then
        log_info "HenSurf.app already exists. Removing before creating a new one." | tee -a "$BUILD_LOG_FILE"
        rm -rf "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app"
    fi

    local EXPECTED_CHROMIUM_APP_NAME="Chromium.app" # Default for is_chrome_branded=false
    local APP_COPIED=false
    if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/${EXPECTED_CHROMIUM_APP_NAME}" ]; then
        log_info "Found ${EXPECTED_CHROMIUM_APP_NAME}, copying to HenSurf.app..." | tee -a "$BUILD_LOG_FILE"
        cp -R "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/${EXPECTED_CHROMIUM_APP_NAME}" "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app"
        APP_COPIED=true
    else
        log_warn "⚠️ Could not find ${EXPECTED_CHROMIUM_APP_NAME} in $FINAL_OUTPUT_DIR to create HenSurf.app." | tee -a "$BUILD_LOG_FILE"
        return 1 # Indicate failure
    fi

    if [ "$APP_COPIED" = true ] && [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app" ]; then
        local PLIST_BUDDY="/usr/libexec/PlistBuddy"
        local INFO_PLIST="$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app/Contents/Info.plist"
        # These should ideally be sourced from a version file or configuration
        local TARGET_MACOS_MIN_VERSION="10.15"
        local HENSURF_VERSION_STR="1.0.0-dev"
        local HENSURF_BUILD_NUMBER_STR="1"

        # PlistBuddy is a macOS specific tool. This check ensures it runs only on a macOS host.
        # The FINAL_TARGET_OS check above ensures we only ATTEMPT this for mac builds.
        # This inner check is for whether the HOST is capable.
        if command_exists "$PLIST_BUDDY" && [ -f "$INFO_PLIST" ]; then
            log_info "Updating Info.plist at: $INFO_PLIST" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleName HenSurf" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warn: Failed to set CFBundleName" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleDisplayName HenSurf Browser" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warn: Failed to set CFBundleDisplayName" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleIdentifier com.hensurf.browser" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warn: Failed to set CFBundleIdentifier" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleShortVersionString '$HENSURF_VERSION_STR'" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warn: Failed to set CFBundleShortVersionString" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :CFBundleVersion '$HENSURF_BUILD_NUMBER_STR'" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warn: Failed to set CFBundleVersion" | tee -a "$BUILD_LOG_FILE"
            "$PLIST_BUDDY" -c "Set :LSMinimumSystemVersion '$TARGET_MACOS_MIN_VERSION'" "$INFO_PLIST" >/dev/null 2>&1 || log_warn "Warn: Failed to set LSMinimumSystemVersion" | tee -a "$BUILD_LOG_FILE"
            # TODO: Add icon file configuration if an app.icns is available
            # "$PLIST_BUDDY" -c "Set :CFBundleIconFile app.icns" "$INFO_PLIST"
            log_success "✅ HenSurf.app bundle Info.plist configured." | tee -a "$BUILD_LOG_FILE"
        else
            if [[ "$(_get_os_type_internal)" == "macos" ]]; then # Host is macOS but PlistBuddy failed
                 log_warn "⚠️ PlistBuddy tool not found or Info.plist missing. Cannot customize app bundle on macOS host." | tee -a "$BUILD_LOG_FILE"
            else # Host is not macOS, so this is expected
                 log_info "ℹ️ Skipping Info.plist customization (PlistBuddy tool typically only available on macOS host)." | tee -a "$BUILD_LOG_FILE"
            fi
        fi
    else
        log_warn "⚠️ HenSurf.app was not successfully copied. Skipping Info.plist configuration." | tee -a "$BUILD_LOG_FILE"
        return 1 # Indicate failure
    fi
    log_success "✅ macOS application bundle created successfully."
}

# Logs the location of build artifacts and provides instructions to run HenSurf.
summarize_build_artifacts() {
    log_info "--- Build Summary ---"
    local EXE_SUFFIX=""
    [[ "$FINAL_TARGET_OS" == "win" ]] && EXE_SUFFIX=".exe"

    log_success "🎉 HenSurf build for $FINAL_TARGET_OS-$FINAL_TARGET_CPU completed successfully!" | tee -a "$BUILD_LOG_FILE"
    log_info "📍 Build artifacts location (relative to $CHROMIUM_SRC_DIR e.g., src/chromium/out/HenSurf-linux-x64):" | tee -a "$BUILD_LOG_FILE"
    log_info "   Main executable: $FINAL_OUTPUT_DIR/chrome${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"

    if [ "$BUILD_CHROMEDRIVER" = true ] && [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/chromedriver${EXE_SUFFIX}" ]; then
        log_info "   ChromeDriver:    $FINAL_OUTPUT_DIR/chromedriver${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"
    fi

    if [[ "$FINAL_TARGET_OS" == "mac" ]]; then
        if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app" ]; then
            log_info "   macOS App Bundle: $FINAL_OUTPUT_DIR/HenSurf.app" | tee -a "$BUILD_LOG_FILE"
        fi
        if [ "$BUILD_MINI_INSTALLER" = true ]; then
            if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.dmg" ]; then
                 log_info "   macOS Installer:  $FINAL_OUTPUT_DIR/HenSurf.dmg" | tee -a "$BUILD_LOG_FILE"
            elif [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/mini_installer.dmg" ]; then # Note: This path is already correct as it uses CHROMIUM_SRC_DIR
                 log_info "   macOS Installer:  $FINAL_OUTPUT_DIR/mini_installer.dmg" | tee -a "$BUILD_LOG_FILE"
            else
                 log_info "   (macOS installer not found at expected paths)" | tee -a "$BUILD_LOG_FILE"
            fi
        fi
    elif [[ "$FINAL_TARGET_OS" == "win" ]]; then
        if [ "$BUILD_MINI_INSTALLER" = true ]; then
            if [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/mini_installer.exe" ]; then
                log_info "   Windows Installer: $FINAL_OUTPUT_DIR/mini_installer.exe" | tee -a "$BUILD_LOG_FILE"
            elif [ -f "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/setup.exe" ]; then
                log_info "   Windows Installer: $FINAL_OUTPUT_DIR/setup.exe" | tee -a "$BUILD_LOG_FILE"
            else
                log_info "   (Windows installer not found at expected paths)" | tee -a "$BUILD_LOG_FILE"
            fi
        fi
    fi
    log_info "   Build log: $BUILD_LOG_FILE" | tee -a "$BUILD_LOG_FILE"
    log_info "" | tee -a "$BUILD_LOG_FILE"
    log_info "🚀 To run HenSurf (from $CHROMIUM_SRC_DIR e.g. src/chromium directory):" | tee -a "$BUILD_LOG_FILE"

    if [[ "$FINAL_TARGET_OS" == "mac" ]]; then
        if [ -d "$CHROMIUM_SRC_DIR/$FINAL_OUTPUT_DIR/HenSurf.app" ]; then
            log_info "   open $FINAL_OUTPUT_DIR/HenSurf.app" | tee -a "$BUILD_LOG_FILE"
        else
            log_info "   ./$FINAL_OUTPUT_DIR/chrome  (App bundle failed/skipped)" | tee -a "$BUILD_LOG_FILE"
        fi
    elif [[ "$FINAL_TARGET_OS" == "win" ]]; then
        log_info "   ./$FINAL_OUTPUT_DIR/chrome${EXE_SUFFIX}" | tee -a "$BUILD_LOG_FILE"
    else # Linux or other
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
}

# Call main function with all script arguments
main "$@"