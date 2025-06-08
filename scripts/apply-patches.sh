#!/usr/bin/env bash

#
# HenSurf Browser - Production Patcher & Build Tool
#
# Description:
#   A comprehensive, idempotent tool to customize the Chromium source code.
#   It applies/reverts patches, stages/deploys branding assets, and configures
#   the build environment. Includes flags for granular control over its behavior.
#
# Usage: ./apply-patches.sh [OPTIONS]
# See --help for more details.
#

# --- Script Configuration & Strict Mode ---
set -euo pipefail

# --- Global Read-only Constants ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly LOG_FILE="${PROJECT_ROOT}/apply-patches.log"
readonly UTILS_SCRIPT_PATH="${SCRIPT_DIR}/utils.sh"

readonly CHROMIUM_SRC_DIR="${PROJECT_ROOT}/src/chromium"
readonly PATCHES_DIR="${PROJECT_ROOT}/src/hensurf/patches"
readonly HENSURF_CONFIG_DIR="${PROJECT_ROOT}/src/hensurf/config"
readonly STAGED_ASSETS_DIR="${PROJECT_ROOT}/src/hensurf/branding/distributable_assets/chromium"
readonly SETUP_LOGO_SCRIPT="${PROJECT_ROOT}/scripts/setup-logo.sh"

# --- CLI Options & State Variables ---
REVERT_PATCHES=false
FORCE_APPLY=false
SKIP_DEPS_CHECK=false
SKIP_ASSET_STAGING=false
NO_COLOR=false

# --- TUI & Logging Setup ---
# TUI Color Codes are defined here and checked against NO_COLOR later.
_C_RESET='' _C_RED='' _C_GREEN='' _C_YELLOW='' _C_BLUE='' _C_BOLD=''
if [[ -t 1 && "${NO_COLOR}" = false ]]; then
    _C_RESET='\033[0m'
    _C_RED='\033[0;31m'
    _C_GREEN='\033[0;32m'
    _C_YELLOW='\033[0;33m'
    _C_BLUE='\033[0;34m'
    _C_BOLD='\033[1m'
fi

# --- State & Cleanup ---
readonly START_TIME=$(date +%s)
FAILURE_LIST=() # Using a global array to track failures.

final_summary() {
    local exit_code=$?
    local end_time; end_time=$(date +%s)
    local total_time=$((end_time - START_TIME))

    echo # Add a newline for spacing
    if [ ${#FAILURE_LIST[@]} -eq 0 ] && [ ${exit_code} -eq 0 ]; then
        _log 'SUCCESS' "All steps completed successfully in ${total_time} seconds!"
    else
        _log 'WARN' "Script finished with issues. Total time: ${total_time} seconds."
        if [ ${#FAILURE_LIST[@]} -gt 0 ]; then
            _log 'WARN' "The following steps reported failures or warnings:"
            for failure in "${FAILURE_LIST[@]}"; do
                printf "%s\n" "${failure}" # Print failures which are pre-formatted
            done
        fi
        _log 'ERROR' "Review the log file '${LOG_FILE}' for complete details."
    fi
    exit "${exit_code}"
}
trap final_summary EXIT

# --- Logging Functions ---
_log() {
    local level="$1"
    local msg="$2"
    local color="${_C_BLUE}"
    
    case "${level}" in
        SUCCESS) color="${_C_GREEN}";;
        WARN)    color="${_C_YELLOW}";;
        ERROR)   color="${_C_RED}";;
    esac

    printf "${color}${_C_BOLD}[%-7s]${_C_RESET} %s\n" "${level}" "${msg}"
    printf "[%s] [%-7s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "${msg}" >> "${LOG_FILE}"
}

_log_progress() {
    local step_name="$1"
    local elapsed=$(( $(date +%s) - START_TIME ))
    _log 'INFO' "---------------- Step '${step_name}' finished. (Elapsed: ${elapsed}s) ----------------"
}

# --- Core Logic Functions ---

usage() {
cat << EOF
${_C_BOLD}HenSurf Browser - Production Patcher & Build Tool${_C_RESET}

${_C_YELLOW}Description:${_C_RESET}
  This script automates the full customization of the Chromium source tree. It can apply
  and revert patches, deploy branding assets, and set up the build environment.

${_C_YELLOW}Usage:${_C_RESET}
  ./apply-patches.sh [OPTIONS]

${_C_YELLOW}Options:${_C_RESET}
  ${_C_GREEN}-h, --help${_C_RESET}
      Show this help message and exit.

  ${_C_GREEN}-r, --revert${_C_RESET}
      Revert all patches before applying them again. Ensures a clean, predictable state.

  ${_C_GREEN}-f, --force-apply${_C_RESET}
      Force patch application even if a dry-run fails. Use with caution.

  ${_C_GREEN}-s, --skip-deps-check${_C_RESET}
      Skip initial dependency checks ('patch', 'rsync'). For advanced users.

  ${_C_GREEN}    --skip-asset-staging, --no-fetch${_C_RESET}
      Skip the asset staging step (running 'setup-logo.sh'). Use if assets are
      already prepared or if you only need to manage patches.
      
  ${_C_GREEN}    --no-color${_C_RESET}
      Disable colored output.

EOF
exit "${1:-0}"
}

preflight_checks() {
    if [ "${SKIP_DEPS_CHECK}" = true ]; then
        _log 'WARN' "Skipping dependency checks as requested."
        return
    fi
    _log 'INFO' "Performing pre-flight checks..."
    
    # shellcheck source=scripts/utils.sh
    source "${UTILS_SCRIPT_PATH}"

    command_exists "patch" || { _log 'ERROR' "'patch' command not found."; exit 1; }
    command_exists "rsync" || _log 'WARN' "'rsync' not found. Will fall back to 'cp', which is less efficient."

    if [ ! -d "${CHROMIUM_SRC_DIR}" ]; then
        _log 'ERROR' "Chromium source not found at '${CHROMIUM_SRC_DIR}'. Run fetch-chromium.sh first."
        exit 1
    fi
    
    local depot_tools_dir; depot_tools_dir=$(get_depot_tools_dir "${PROJECT_ROOT}")
    add_depot_tools_to_path "${depot_tools_dir}" || { _log 'ERROR' "Failed to configure depot_tools."; exit 1; }
    
    _log 'SUCCESS' "Pre-flight checks passed."
}

stage_branding_assets() {
    if [ "${SKIP_ASSET_STAGING}" = true ]; then
        _log 'WARN' "Skipping asset staging as requested by --skip-asset-staging."
        return
    fi
    
    _log 'INFO' "Staging branding assets by executing 'setup-logo.sh'..."
    if [ ! -f "${SETUP_LOGO_SCRIPT}" ]; then
        _log 'ERROR' "'setup-logo.sh' not found. Cannot stage branding assets."
        FAILURE_LIST+=("  - ${_C_RED}setup-logo.sh${_C_RESET}: Script not found.")
        return
    fi

    chmod +x "${SETUP_LOGO_SCRIPT}"
    if (cd "${PROJECT_ROOT}" && "${SETUP_LOGO_SCRIPT}" >> "${LOG_FILE}" 2>&1); then
        _log 'SUCCESS' "'setup-logo.sh' executed successfully."
    else
        _log 'WARN' "'setup-logo.sh' reported errors. Staged assets may be incomplete."
        FAILURE_LIST+=("  - ${_C_YELLOW}setup-logo.sh${_C_RESET}: Execution reported errors.")
    fi
}

manage_patches() {
    _log 'INFO' "Entering patch management..."
    safe_cd "${CHROMIUM_SRC_DIR}"

    local patches_to_apply=(
        "integrate-logo.patch|Logo Integration"
        "feature-default-search-engine.patch|Default Search Engine"
        "feature-disable-google-apis.patch|Disable Google APIs"
        "feature-disable-crash-reporting.patch|Disable Crash Reporting"
        "feature-update-version-info.patch|Update Version Info"
        "feature-custom-user-agent-file.patch|Custom User Agent"
    )

    if [ "${REVERT_PATCHES}" = true ]; then
        _log 'INFO' "Reverting patches as requested..."
        for (( i=${#patches_to_apply[@]}-1; i>=0; i-- )); do
            local patch_info="${patches_to_apply[$i]}"
            local description="${patch_info#*|}"
            
            if patch -p1 --reverse < "${PATCHES_DIR}/${patch_info%|*}" >> "${LOG_FILE}" 2>&1; then
                _log 'SUCCESS' "--> Reverted: '${description}'"
            else
                _log 'WARN' "--> Reverting '${description}' failed. It may not have been applied."
            fi
        done
        _log 'SUCCESS' "Patch reversion phase complete."
    fi

    _log 'INFO' "Applying patches..."
    for patch_info in "${patches_to_apply[@]}"; do
        local description="${patch_info#*|}"
        local full_path="${PATCHES_DIR}/${patch_info%|*}"

        if patch -p1 --forward --dry-run < "${full_path}" >/dev/null 2>&1; then
            if patch -p1 --forward < "${full_path}" >> "${LOG_FILE}" 2>&1; then
                _log 'SUCCESS' "--> Applied: '${description}'"
            else
                _log 'ERROR' "Patch '${description}' failed unexpectedly after a successful dry run."
                FAILURE_LIST+=("  - ${_C_RED}${description}${_C_RESET}: Failed on application.")
            fi
        else
            if [ $? -eq 1 ]; then
                 if [ "${FORCE_APPLY}" = true ]; then
                    _log 'WARN' "Dry run failed for '${description}', but forcing application..."
                    if patch -p1 --forward < "${full_path}" >> "${LOG_FILE}" 2>&1; then
                        _log 'SUCCESS' "--> Force-Applied: '${description}'"
                    else
                        _log 'ERROR' "Force-application of '${description}' failed."
                        FAILURE_LIST+=("  - ${_C_RED}${description}${_C_RESET}: Failed on force-application.")
                    fi
                else
                    _log 'WARN' "--> Skipping '${description}' (already applied or has conflicts)."
                fi
            else
                _log 'ERROR' "Dry run for '${description}' failed with a critical error."
                FAILURE_LIST+=("  - ${_C_RED}${description}${_C_RESET}: Critical patch error.")
            fi
        fi
    done
}

configure_build_environment() {
    _log 'INFO' "Creating default build configuration..."
    mkdir -p "${CHROMIUM_SRC_DIR}/out/HenSurf"
    cp "${HENSURF_CONFIG_DIR}/hensurf.gn" "${CHROMIUM_SRC_DIR}/out/HenSurf/args.gn"
    _log 'SUCCESS' "Default build configuration created at out/HenSurf/args.gn."
}

remove_unwanted_content() {
    _log 'INFO' "Removing promotional and welcome files..."
    find "${CHROMIUM_SRC_DIR}/chrome/browser/ui" -name "*promo*" -type f -delete >> "${LOG_FILE}" 2>&1 || true
    find "${CHROMIUM_SRC_DIR}/chrome/browser/ui" -name "*welcome*" -type f -delete >> "${LOG_FILE}" 2>&1 || true
    _log 'SUCCESS' "Content removal attempt finished."
}

deploy_assets() {
    _log 'INFO' "Deploying staged branding assets to Chromium source..."
    if [ ! -d "${STAGED_ASSETS_DIR}" ]; then
        _log 'WARN' "Staged assets directory not found at '${STAGED_ASSETS_DIR}'. Skipping deployment."
        FAILURE_LIST+=("  - ${_C_YELLOW}Asset Deployment${_C_RESET}: Staged assets directory missing.")
        return
    fi

    if command_exists "rsync"; then
        rsync -a --relative "${STAGED_ASSETS_DIR}/./" "${CHROMIUM_SRC_DIR}"
        _log 'SUCCESS' "Branding assets deployed successfully using rsync."
    else
        _log 'WARN' "Using 'cp' fallback for asset deployment."
        (cd "${STAGED_ASSETS_DIR}" && find . -type f -exec cp --parents -v {} "${CHROMIUM_SRC_DIR}" \;) >> "${LOG_FILE}" 2>&1
        _log 'SUCCESS' "Branding assets deployed using cp."
    fi
}

# --- Main Execution Function ---
main() {
    true > "${LOG_FILE}" # Clear log file
    _log 'INFO' "Starting HenSurf Patcher. Log file: ${LOG_FILE}"

    preflight_checks
    _log_progress "PRE-FLIGHT CHECKS"
    
    stage_branding_assets
    _log_progress "ASSET STAGING"

    safe_cd "${CHROMIUM_SRC_DIR}"
    
    configure_build_environment
    _log_progress "BUILD CONFIGURATION"
    
    manage_patches
    _log_progress "PATCH MANAGEMENT"

    remove_unwanted_content
    _log_progress "CONTENT REMOVAL"

    deploy_assets
    _log_progress "ASSET DEPLOYMENT"
}

# --- Script Entry Point ---
# Parse Command-Line Arguments
if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)              usage ;;
            -r|--revert)            REVERT_PATCHES=true; shift ;;
            -f|--force-apply)       FORCE_APPLY=true; shift ;;
            -s|--skip-deps-check)   SKIP_DEPS_CHECK=true; shift ;;
            --skip-asset-staging|--no-fetch) SKIP_ASSET_STAGING=true; shift ;;
            --no-color)             NO_COLOR=true; shift ;;
            *)
                echo -e "${_C_RED}Unknown option: $1${_C_RESET}"
                usage 1
                ;;
        esac
    done
fi

main "$@"
