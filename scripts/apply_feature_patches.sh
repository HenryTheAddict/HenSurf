#!/usr/bin/env bash

# ===================================================================================
#
# HenSurf Browser - Feature Patch Management Tool
#
# Author: [Your Name/Team]
# Version: 2.0.0
#
# -----------------------------------------------------------------------------------
#
# DESCRIPTION:
#   A robust tool for managing feature patches within the Chromium source tree.
#   It safely applies, unapplies, and tracks the status of patches, ensuring
#   a clean and predictable development environment.
#
# COMMANDS:
#   apply   <feature_name>  Applies a patch if it is not already applied.
#   unapply <feature_name>  Unapplies a patch if it is currently applied.
#   status                  Lists all available patches and their current status.
#
# OPTIONS:
#   --force                 Proceed even if the Git working directory is not clean.
#                           Requires interactive confirmation.
#
# PREREQUISITES:
#   - Must be run from the root of a Git repository.
#   - The 'git' command-line tool must be installed and in the system's PATH.
#
# ===================================================================================

# --- Script Configuration ---
set -euo pipefail

# Directory containing the .patch files, relative to the project root.
readonly PATCH_DIR="src/hensurf/patches"
# File to store the state of applied patches. Located in .git for portability.
readonly STATE_FILE=".git/hensurf_patch_state"
# Project root, determined by the location of the .git directory.
readonly PROJECT_ROOT=$(git rev-parse --show-toplevel)

# --- Theming and Color ---
if [[ -t 1 ]]; then
    readonly C_RESET='\033[0m'
    readonly C_RED='\033[0;31m'
    readonly C_GREEN='\033[0;32m'
    readonly C_YELLOW='\033[0;33m'
    readonly C_BLUE='\033[0;34m'
    readonly C_CYAN='\033[0;36m'
    readonly C_BOLD='\033[1m'
else
    # Disable colors if not in an interactive terminal
    readonly C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN='' C_BOLD=''
fi

# --- Logging Functions ---
log_info() { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2; }
log_success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"; }
log_warn() { echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "[DEBUG] $1"; }

# --- Core Logic Functions ---

# Displays detailed usage instructions and exits.
usage() {
    cat <<EOF
${C_BOLD}HenSurf Patch Management Tool${C_RESET}

${C_BOLD}Usage:${C_RESET} $0 <command> [options]

${C_BOLD}Commands:${C_RESET}
  ${C_CYAN}apply <feature>${C_RESET}      Applies the patch for the specified feature.
  ${C_CYAN}unapply <feature>${C_RESET}    Unapplies the patch for the specified feature.
  ${C_CYAN}status${C_RESET}               Show the status of all available patches.

${C_BOLD}Options:${C_RESET}
  ${C_YELLOW}--force${C_RESET}             Allow operations on a dirty working tree (prompts for confirmation).
  ${C_YELLOW}-h, --help${C_RESET}          Display this help message.

${C_BOLD}Example:${C_RESET}
  $0 apply remove-ads
EOF
    exit 1
}

# Performs initial checks for dependencies and repository state.
run_initial_checks() {
    log_debug "Running initial system checks."
    if ! command -v git &> /dev/null; then
        log_error "git is not installed. This script requires git to function."
        exit 1
    fi
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        log_error "This script must be run from within a git repository."
        exit 1
    fi
    # Ensure the state file exists
    touch "${PROJECT_ROOT}/${STATE_FILE}"
}

# Checks if the Git working tree has uncommitted changes.
check_working_tree_is_clean() {
    if ! git diff-index --quiet HEAD --; then
        log_warn "Your working directory has uncommitted changes."
        if [[ "${FORCE_APPLY:-0}" -eq 0 ]]; then
            log_error "Aborting to prevent data loss. Stash or commit your changes, or use --force."
            exit 1
        else
            log_warn "The --force flag is active."
            read -p "  Are you sure you want to proceed? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Aborted by user."
                exit 1
            fi
        fi
    fi
}

# Checks if a given patch is marked as applied in the state file.
# Returns 0 if applied, 1 otherwise.
is_patch_applied() {
    local feature_name="$1"
    grep -qxF "${feature_name}" "${PROJECT_ROOT}/${STATE_FILE}"
}

# Updates the state file to mark a patch as applied or unapplied.
update_patch_state() {
    local feature_name="$1"
    local new_status="$2" # "applied" or "unapplied"

    if [[ "$new_status" == "applied" ]]; then
        # Add to state file if not already present
        is_patch_applied "${feature_name}" || echo "${feature_name}" >> "${PROJECT_ROOT}/${STATE_FILE}"
    else
        # Remove from state file
        sed -i -e "/^${feature_name}$/d" "${PROJECT_ROOT}/${STATE_FILE}"
    fi
    log_debug "State for '${feature_name}' updated to '${new_status}'."
}

# The main function that orchestrates the script's execution.
main() {
    run_initial_checks

    # --- Flexible Argument Parsing ---
    local action=""
    local feature_name=""
    FORCE_APPLY=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            apply|unapply|status)
                [[ -n "$action" ]] && log_error "Only one command can be used at a time." && usage
                action="$1"
                shift
                if [[ "$action" != "status" && $# -gt 0 && ! "$1" =~ ^-- ]]; then
                    feature_name="$1"
                    shift
                fi
                ;;
            --force)
                FORCE_APPLY=1
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option or command: $1"
                usage
                ;;
        esac
    done

    # --- Command Dispatcher ---
    case "${action}" in
        apply)
            [[ -z "$feature_name" ]] && log_error "The 'apply' command requires a feature name." && usage
            local patch_file="${PROJECT_ROOT}/${PATCH_DIR}/${feature_name}.patch"
            
            if [[ ! -f "$patch_file" ]]; then
                log_error "Patch file not found: '$patch_file'"
                exit 1
            fi

            if is_patch_applied "${feature_name}"; then
                log_info "Patch '${feature_name}' is already applied. No action taken."
                exit 0
            fi

            check_working_tree_is_clean
            
            log_info "Running a dry-run to pre-check the patch..."
            if ! git apply --check --reject --ignore-whitespace --unidiff-zero "$patch_file"; then
                log_error "Pre-check failed. The patch cannot be applied cleanly."
                exit 1
            fi

            log_info "Applying patch..."
            if git apply --reject --ignore-whitespace --unidiff-zero "$patch_file"; then
                update_patch_state "${feature_name}" "applied"
                log_success "Patch '${feature_name}' applied successfully."
            else
                log_error "Failed to apply patch '${feature_name}'. Review any '.rej' files."
                exit 1
            fi
            ;;
        unapply)
            [[ -z "$feature_name" ]] && log_error "The 'unapply' command requires a feature name." && usage
            local patch_file="${PROJECT_ROOT}/${PATCH_DIR}/${feature_name}.patch"

            if ! is_patch_applied "${feature_name}"; then
                log_info "Patch '${feature_name}' is not applied. No action taken."
                exit 0
            fi

            check_working_tree_is_clean

            log_info "Unapplying patch..."
            if git apply --reverse --reject --ignore-whitespace --unidiff-zero "$patch_file"; then
                update_patch_state "${feature_name}" "unapplied"
                log_success "Patch '${feature_name}' unapplied successfully."
            else
                log_error "Failed to unapply patch '${feature_name}'. The code may have changed."
                exit 1
            fi
            ;;
        status)
            log_info "Checking status of available patches in '${PATCH_DIR}'..."
            echo "--------------------------------------------------"
            if ! ls -1 "${PROJECT_ROOT}/${PATCH_DIR}/"*.patch &>/dev/null; then
                log_warn "No patches found in the directory."
            else
                for patch_file in "${PROJECT_ROOT}/${PATCH_DIR}/"*.patch; do
                    local f_name
                    f_name=$(basename "$patch_file" .patch)
                    if is_patch_applied "$f_name"; then
                        echo -e "  [ ${C_GREEN}Applied${C_RESET} ]   ${f_name}"
                    else
                        echo -e "  [ Not Applied ] ${f_name}"
                    fi
                done
            fi
            echo "--------------------------------------------------"
            ;;
        *)
            log_error "No command specified."
            usage
            ;;
    esac
}

# --- Script Entrypoint ---
# This construct ensures the main logic runs only when the script is executed directly.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
