#!/bin/bash

# HenSurf Browser - Chromium Source Fetch Script
# This script downloads the Chromium source code

set -e

# Determine script and project paths
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." &>/dev/null && pwd)

# Source utility functions
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR/utils.sh" # utils.sh provides logging and safe_cd functions

log_info "🌐 Fetching Chromium source code for HenSurf..."


# depot_tools path logic:
# 1. Check DEPOT_TOOLS_PATH environment variable
# 2. Fallback to common locations ($PROJECT_ROOT/../depot_tools or $PROJECT_ROOT/depot_tools)

DEPOT_TOOLS_DIR=""
if [ -n "$DEPOT_TOOLS_PATH" ] && [ -d "$DEPOT_TOOLS_PATH" ]; then
    DEPOT_TOOLS_DIR=$(cd "$DEPOT_TOOLS_PATH" &>/dev/null && pwd) # Get absolute path
    log_info "ℹ️ Using depot_tools from DEPOT_TOOLS_PATH environment variable: $DEPOT_TOOLS_DIR"
else
    # Try to find depot_tools, assuming it's adjacent to the project root
    DEPOT_TOOLS_DIR_GUESS_1="$PROJECT_ROOT/../depot_tools"
    # Fallback if it's inside the project root
    DEPOT_TOOLS_DIR_GUESS_2="$PROJECT_ROOT/depot_tools"

    if [ -d "$DEPOT_TOOLS_DIR_GUESS_1" ]; then
        DEPOT_TOOLS_DIR=$(cd "$DEPOT_TOOLS_DIR_GUESS_1" &>/dev/null && pwd)
        log_info "ℹ️ Using depot_tools from default location (adjacent to project): $DEPOT_TOOLS_DIR"
    elif [ -d "$DEPOT_TOOLS_DIR_GUESS_2" ]; then
        DEPOT_TOOLS_DIR=$(cd "$DEPOT_TOOLS_DIR_GUESS_2" &>/dev/null && pwd)
        log_info "ℹ️ Using depot_tools from fallback location (inside project): $DEPOT_TOOLS_DIR"
    else
        log_error "❌ depot_tools not found."
        log_error "   Checked DEPOT_TOOLS_PATH environment variable (was not set or invalid)."
        log_error "   Checked default location: $DEPOT_TOOLS_DIR_GUESS_1"
        log_error "   Checked fallback location: $DEPOT_TOOLS_DIR_GUESS_2"
        log_error "   Please ensure depot_tools is correctly installed and accessible,"
        log_error "   or set the DEPOT_TOOLS_PATH environment variable to its location."
        log_error "   Consider running ./scripts/install-deps.sh first if depot_tools is not yet installed."
        exit 1
    fi
fi

export PATH="$DEPOT_TOOLS_DIR:$PATH"
log_info "🔧 Added depot_tools to PATH for this session."

# Check available disk space
MIN_DISK_SPACE_GB=100 # Minimum recommended disk space in GB
AVAILABLE_SPACE_GB=0
HOST_OS_FOR_DISK_CHECK=$(_get_os_type_internal) # Use generic OS type for this check (macos, linux, windows)

if [[ "$HOST_OS_FOR_DISK_CHECK" == "macos" ]] || [[ "$HOST_OS_FOR_DISK_CHECK" == "linux" ]]; then
    # df -BG . : Get free space in GB for the current directory's filesystem.
    # awk 'NR==2 {print $4}' : From the output, take the second line and fourth field (Available).
    # sed 's/G//' : Remove the 'G' suffix.
    # tr -d '[:space:]' : Remove any whitespace.
    AVAILABLE_SPACE_GB=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//' | tr -d '[:space:]' || echo 0)
    log_info "Disk space check ($HOST_OS_FOR_DISK_CHECK): ${AVAILABLE_SPACE_GB}GB available in current directory's partition."
elif [[ "$HOST_OS_FOR_DISK_CHECK" == "windows" ]]; then
    log_info "💻 Checking disk space on Windows..."
    CURRENT_DRIVE_LETTER=$(pwd -W | cut -d':' -f1) # Get current drive letter (e.g., C)
    if ! command_exists "wmic"; then
        log_warn "⚠️ 'wmic' command not found. Cannot check disk space accurately on Windows."
        log_warn "   Please ensure at least ${MIN_DISK_SPACE_GB}GB is available on drive ${CURRENT_DRIVE_LETTER}."
        AVAILABLE_SPACE_GB=0 # Default to trigger manual confirmation if wmic fails
    else
        # wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value
        # Fetches FreeSpace in bytes. Output needs parsing.
        AVAILABLE_BYTES_STR=$(wmic logicaldisk where "DeviceID='${CURRENT_DRIVE_LETTER}:'" get FreeSpace /value 2>/dev/null | tr -d '\r' | grep FreeSpace | cut -d'=' -f2)
        if [[ -z "$AVAILABLE_BYTES_STR" || ! "$AVAILABLE_BYTES_STR" =~ ^[0-9]+$ ]]; then
             log_warn "⚠️ Could not determine free space using wmic for drive ${CURRENT_DRIVE_LETTER}: (Raw output: '$AVAILABLE_BYTES_STR')."
             AVAILABLE_SPACE_GB=0 # Assume not enough if parsing fails
        else
            # Convert bytes to GB using awk for floating point arithmetic.
            AVAILABLE_SPACE_GB=$(awk -v bytes="$AVAILABLE_BYTES_STR" 'BEGIN { printf "%.0f", bytes / 1024 / 1024 / 1024 }')
        fi
    fi
    log_info "Drive ${CURRENT_DRIVE_LETTER}: has approximately ${AVAILABLE_SPACE_GB}GB free."
else
    log_warn "⚠️ Unsupported OS ('$HOST_OS_FOR_DISK_CHECK') for automated disk space check. Assuming ${MIN_DISK_SPACE_GB}GB available."
    AVAILABLE_SPACE_GB=${MIN_DISK_SPACE_GB} # Assume enough to proceed, user should verify.
fi

# Final validation of AVAILABLE_SPACE_GB before comparison
if ! [[ "$AVAILABLE_SPACE_GB" =~ ^[0-9]+$ ]]; then # If not a number (e.g. parsing failed)
    log_warn "⚠️ Could not reliably determine available disk space (parsed as '$AVAILABLE_SPACE_GB'). Defaulting to 0 for safety."
    AVAILABLE_SPACE_GB=0
fi

if [ "$AVAILABLE_SPACE_GB" -lt "$MIN_DISK_SPACE_GB" ]; then
    log_warn "⚠️ Warning: Only ${AVAILABLE_SPACE_GB}GB detected as available. Chromium source requires at least ${MIN_DISK_SPACE_GB}GB."
    read -r -p "Continue anyway? (y/N): " REPLY
    echo # Move to a new line after input
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        log_error "User aborted due to low disk space."
        exit 1
    fi
fi

# Define HenSurf root and Chromium directory path (relative to HenSurf root)
HENSURF_ROOT_DIR="$PROJECT_ROOT"
CHROMIUM_DIR="$HENSURF_ROOT_DIR/chromium"

if [ ! -d "$CHROMIUM_DIR" ]; then
    log_info "📁 Creating chromium directory at $CHROMIUM_DIR..."
    mkdir -p "$CHROMIUM_DIR"
fi

safe_cd "$CHROMIUM_DIR" # log_info for success is part of safe_cd

# Check if .gclient exists (indicates previous fetch)
if [ -f ".gclient" ]; then
    log_info "🔄 Updating existing Chromium source via 'gclient sync'..."
    gclient sync
else
    log_info "📦 Fetching new Chromium source via 'fetch --nohooks chromium' (this will take a while)..."
    log_info "⏳ Expected time: 30-60 minutes or more depending on internet speed and machine specs."
    
    fetch --nohooks chromium # Creates 'src' directory and .gclient file
    
    log_info "🔧 Running gclient hooks..."
    if [ ! -f ".gclient" ]; then
        log_error "❌ .gclient file not found in $(pwd) after fetch. This is unexpected."
        log_error "   Ensure 'fetch --nohooks chromium' completed successfully."
        exit 1
    fi
    if [ ! -d "src" ]; then # 'fetch chromium' creates src/, so this should exist
        log_error "❌ 'src' directory not found in $(pwd) after fetch. This is unexpected."
        exit 1
    fi
    gclient runhooks
fi

log_info "✅ Chromium source code sync/fetch operation completed."
log_info "   Source code is in: $(pwd)/src"
log_info ""
read -r -p "Do you want to perform an enhanced sync with all branch heads and tags? (Useful for checking out specific versions or full history, but takes more time/space) (y/N): " ENHANCED_SYNC_REPLY
echo
if [[ "$ENHANCED_SYNC_REPLY" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    log_info "🚀 Performing enhanced sync: gclient sync --with_branch_heads --with_tags..."
    if gclient sync --with_branch_heads --with_tags; then
        log_success "✅ Enhanced sync completed successfully."
    else
        log_error "❌ Enhanced sync failed. Please check the output above."
        # Do not exit, as the basic sync might have been sufficient.
    fi
else
    log_info "ℹ️ Skipping enhanced sync."
fi


log_info ""
log_success "✅ Chromium source code is ready in $(pwd)/src!"
log_info ""
log_info "Next steps:"
log_info "1. Run $HENSURF_ROOT_DIR/scripts/apply-patches.sh to apply HenSurf customizations"
log_info "2. Run $HENSURF_ROOT_DIR/scripts/build.sh to build HenSurf"