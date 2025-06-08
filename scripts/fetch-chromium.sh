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

# Find depot_tools using the utility function
DEPOT_TOOLS_DIR=""
if ! DEPOT_TOOLS_DIR=$(find_depot_tools_path "$PROJECT_ROOT"); then
    # Error messages are handled by find_depot_tools_path
    log_error "   Consider running ./scripts/install-deps.sh first if depot_tools is not yet installed."
    exit 1
fi

# Add depot_tools to PATH (find_depot_tools_path already logs the path found)
if ! add_depot_tools_to_path "$DEPOT_TOOLS_DIR"; then
    log_error "Failed to add depot_tools to PATH. Exiting."
    exit 1
fi
# No need for separate log_info for adding to path, add_depot_tools_to_path handles it.

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

# Define HenSurf root and the parent directory for the Chromium checkout
HENSURF_ROOT_DIR="$PROJECT_ROOT"
# Chromium source will be checked out into $PROJECT_ROOT/src/chromium
# depot_tools 'fetch' command creates a directory named 'src' by default.
# So we'll cd into $PROJECT_ROOT/src, run fetch (which creates $PROJECT_ROOT/src/src),
# then rename $PROJECT_ROOT/src/src to $PROJECT_ROOT/src/chromium.
CHROMIUM_PARENT_DIR="$HENSURF_ROOT_DIR/src"
TARGET_CHROMIUM_DIR_NAME="chromium" # The final directory name for chromium source
FETCH_CREATED_DIR_NAME="src"      # Name of directory 'fetch chromium' creates

if [ ! -d "$CHROMIUM_PARENT_DIR" ]; then
    log_info "📁 Creating parent directory for Chromium checkout at $CHROMIUM_PARENT_DIR..."
    mkdir -p "$CHROMIUM_PARENT_DIR"
fi

safe_cd "$CHROMIUM_PARENT_DIR" # log_info for success is part of safe_cd

# Check if the target chromium directory (e.g., src/chromium) or its .gclient already exists
# This indicates a previous fetch.
if [ -f "$TARGET_CHROMIUM_DIR_NAME/.gclient" ] || [ -d "$TARGET_CHROMIUM_DIR_NAME/src" ]; then # 'src' here refers to chromium's internal src, not our top level 'src'
    log_info "Chromium checkout already detected at $TARGET_CHROMIUM_DIR_NAME."
    safe_cd "$TARGET_CHROMIUM_DIR_NAME"
    log_info "🔄 Updating existing Chromium source via 'gclient sync' in $(pwd)..."
    gclient sync; local GCLIENT_SYNC_STATUS=$?
    if [ "$GCLIENT_SYNC_STATUS" -ne 0 ]; then
        log_error "Error: 'gclient sync' failed with status $GCLIENT_SYNC_STATUS in $(pwd)."
        log_error "Please check the output above for specific error messages from gclient."
        exit 1
    fi
    # cd back to parent for consistency before enhanced sync prompt
    safe_cd "$CHROMIUM_PARENT_DIR"
else
    log_info "📦 Fetching new Chromium source via 'fetch --nohooks chromium' into $(pwd)..."
    log_info "   This will create a directory named '$FETCH_CREATED_DIR_NAME' here."
    log_info "⏳ Expected time: 30-60 minutes or more depending on internet speed and machine specs."
    
    fetch --nohooks chromium # Creates './src' (e.g. $PROJECT_ROOT/src/src)
    local FETCH_STATUS=$?

    if [ "$FETCH_STATUS" -ne 0 ]; then
        log_error "Error: 'fetch --nohooks chromium' command failed with status $FETCH_STATUS."
        log_error "This could be due to network issues, incorrect 'fetch' command setup, or other problems during the Chromium source download."
        exit 1
    fi

    if [ ! -d "$FETCH_CREATED_DIR_NAME" ]; then
        log_error "Error: 'fetch --nohooks chromium' completed, but the expected directory '$FETCH_CREATED_DIR_NAME' was not created in $(pwd)."
        log_error "This could be due to an issue with the fetch process, network problems, or insufficient permissions."
        exit 1
    fi
    
    # Rename the fetched 'src' directory to 'chromium'
    if [ -d "$FETCH_CREATED_DIR_NAME" ]; then
        log_info "Renaming fetched directory '$FETCH_CREATED_DIR_NAME' to '$TARGET_CHROMIUM_DIR_NAME'..."
        mv "$FETCH_CREATED_DIR_NAME" "$TARGET_CHROMIUM_DIR_NAME"
        log_success "✅ Renamed to $TARGET_CHROMIUM_DIR_NAME."
    else
        log_error "❌ Directory '$FETCH_CREATED_DIR_NAME' not found after fetch. Cannot rename."
        exit 1
    fi

    safe_cd "$TARGET_CHROMIUM_DIR_NAME" # cd into src/chromium

    log_info "🔧 Running gclient hooks in $(pwd)..."
    if [ ! -f ".gclient" ]; then # .gclient should be in src/chromium now
        log_error "❌ .gclient file not found in $(pwd) after fetch and rename. This is unexpected."
        log_error "   Ensure 'fetch --nohooks chromium' completed successfully."
        exit 1
    fi
    # Chromium's own 'src' directory is one level deeper now, e.g. src/chromium/src - this check is not needed here.
    # if [ ! -d "src" ]; then
    #     log_error "❌ 'src' directory not found in $(pwd) after fetch. This is unexpected."
    #     exit 1
    # fi
    gclient runhooks; local GCLIENT_RUNHOOKS_STATUS=$?
    if [ "$GCLIENT_RUNHOOKS_STATUS" -ne 0 ]; then
        log_error "Error: 'gclient runhooks' failed with status $GCLIENT_RUNHOOKS_STATUS in $(pwd)."
        log_error "This often indicates issues with dependencies or hooks configuration. Check output above."
        exit 1
    fi
    # cd back to parent for consistency before enhanced sync prompt
    safe_cd "$CHROMIUM_PARENT_DIR"
fi

log_info "✅ Chromium source code sync/fetch operation completed."
log_info "   Source code is in: $CHROMIUM_PARENT_DIR/$TARGET_CHROMIUM_DIR_NAME"
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
log_success "✅ Chromium source code is ready in $CHROMIUM_PARENT_DIR/$TARGET_CHROMIUM_DIR_NAME!"
log_info ""
log_info "Next steps:"
log_info "1. Run $HENSURF_ROOT_DIR/scripts/apply-patches.sh to apply HenSurf customizations"
log_info "2. Run $HENSURF_ROOT_DIR/scripts/build.sh to build HenSurf"