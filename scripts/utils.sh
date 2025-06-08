#!/bin/bash

# HenSurf Browser - Shared Utility Script
#
# Purpose:
# This script provides a collection of reusable shell functions for common tasks
# such as logging, OS detection, command checking, and more. It's designed to
# be sourced by other scripts in the project to promote consistency and
# reduce code duplication.
#
# How to Source:
# To use these utilities in your script, source this file at the beginning:
#   source "$(dirname "$0")/utils.sh" # Assuming utils.sh is in the same directory
#   source "path/to/scripts/utils.sh" # Or provide a relative/absolute path
#
# Make sure this script is executable: chmod +x utils.sh

# --- Logging Utilities ---

# Internal function to log messages with a timestamp and level.
# Not intended for direct use; use log_info, log_warn, log_error, log_success instead.
#
# Arguments:
#   $1: level - The log level (e.g., "INFO", "WARN", "ERROR", "SUCCESS").
#   $@: message - The message to log.
_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp; timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# Logs an informational message.
# Arguments:
#   $@: message - The message to log.
log_info() {
    _log "INFO" "$@"
}

# Logs a warning message.
# Arguments:
#   $@: message - The message to log.
log_warn() {
    _log "WARN" "$@"
}

# Logs an error message.
# Arguments:
#   $@: message - The message to log.
log_error() {
    _log "ERROR" "$@"
}

# Logs a success message.
# Arguments:
#   $@: message - The message to log.
log_success() {
    _log "SUCCESS" "$@"
}

# Logs an action message, typically for user interaction steps.
# Uses a distinct color/prefix if the terminal supports it (handled by _log if extended).
# Arguments:
#   $@: message - The message to log.
log_action() {
    # For now, using INFO level but could be customized later if _log supports more colors/styles
    _log "ACTION" "$@"
}

# --- OS Detection ---

# Function to get current OS type (internal helper)
# Returns "macos", "linux", "windows", or "unknown"
_get_os_type_internal() {
    case "$OSTYPE" in
        darwin*) echo "macos" ;;
        linux-gnu*) echo "linux" ;;
        cygwin*|msys*|win32*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Function to get the OS and distribution (if applicable)
# Returns:
#   - "macos" for macOS
#   - "windows" for Windows
#   - Linux distribution ID (e.g., "ubuntu", "fedora", "arch", "centos") for Linux
#   - "linux" if the distribution cannot be determined but OS is Linux
#   - "unknown" if the OS cannot be determined
get_os_distro() {
    local os_type
    os_type=$(_get_os_type_internal)

    if [ "$os_type" = "linux" ]; then
        if [ -f "/etc/os-release" ]; then
            # Source /etc/os-release to get distribution info
            # shellcheck disable=SC1091
            . /etc/os-release
            if [ -n "$ID" ]; then
                echo "$ID" # e.g., ubuntu, fedora, arch
                return 0
            fi
        elif [ -f "/etc/lsb-release" ]; then
            # shellcheck disable=SC1091
            . /etc/lsb-release
            if [ -n "$DISTRIB_ID" ]; then
                echo "$DISTRIB_ID" | tr '[:upper:]' '[:lower:]' # e.g., Ubuntu -> ubuntu
                return 0
            fi
        elif command_exists "rpm"; then
             if rpm -q --quiet system-release || rpm -q --quiet centos-release || rpm -q --quiet fedora-release || rpm -q --quiet redhat-release-server; then
                # Try to get ID from rpm query
                if rpm -q --quiet fedora-release; then echo "fedora"; return 0; fi
                if rpm -q --quiet centos-release; then echo "centos"; return 0; fi
                if rpm -q --quiet redhat-release-server; then echo "rhel"; return 0; fi
                # Add more rpm checks if needed for other distributions
            fi
        fi
        echo "linux" # Fallback if specific distro couldn't be identified
    else
        echo "$os_type" # macos, windows, unknown
    fi
}


# --- Directory and Command Utilities ---

# Safely changes the current directory.
# If 'cd' fails, logs an error and exits the script with status 1.
#
# Arguments:
#   $1: directory_path - The path to the directory to change to.
safe_cd() {
    local dir_path="$1"
    if [ -z "$dir_path" ]; then
        log_error "safe_cd: No directory path provided."
        exit 1
    fi
    if ! cd "$dir_path"; then
        log_error "Failed to change directory to '$dir_path'."
        exit 1
    else
        log_info "Changed directory to '$dir_path'."
    fi
}

# Function to check if a command exists.
#
# Arguments:
#   $1: command_name - The name of the command to check.
#
# Returns:
#   0 if the command exists, 1 otherwise.
# Outputs:
#   No direct output, but 'command -v' might produce output to stderr if options are wrong,
#   which is suppressed here.
command_exists() {
    command -v "$1" &> /dev/null
}

# --- Python Utilities ---

# Function to check Python version.
#
# Arguments:
#   $1: required_major - The minimum required major Python version (e.g., 3).
#   $2: required_minor - The minimum required minor Python version (e.g., 8).
#   $3: python_executable_name (optional) - The Python command to check (e.g., "python3.9"). Defaults to "python3".
#
# Returns:
#   0 if a compatible Python version is found and executable.
#   1 if a compatible Python version is not found, if the command is not found,
#     or if the version cannot be parsed.
# Outputs:
#   Logs details about the Python version check (success, error, or warnings).
check_python_version() {
    local required_major="$1"
    local required_minor="$2"
    local python_cmd="${3:-python3}" # Default to python3

    if ! command_exists "$python_cmd"; then
        # Try 'python' if default 'python3' or provided command not found
        if [[ "$python_cmd" == "python3" ]] && command_exists "python"; then
            python_cmd="python"
        else
            log_error "Python command '$python_cmd' not found. Please install Python $required_major.$required_minor or newer."
            return 1
        fi
    fi

    local python_version_full
    if ! python_version_full=$($python_cmd --version 2>&1); then
        log_error "Failed to get Python version from '$python_cmd'. Output: $python_version_full"
        return 1
    fi

    local python_version
    python_version=$(echo "$python_version_full" | cut -d' ' -f2 | cut -d'.' -f1,2)

    local current_major
    local current_minor
    current_major=$(echo "$python_version" | cut -d'.' -f1)
    current_minor=$(echo "$python_version" | cut -d'.' -f2)

    if [[ -z "$current_major" || -z "$current_minor" ]]; then
        log_error "Could not parse Python version from '$python_version_full'."
        return 1
    fi

    if [ "$current_major" -lt "$required_major" ] ||        { [ "$current_major" -eq "$required_major" ] && [ "$current_minor" -lt "$required_minor" ]; }; then
        log_error "Python version $python_version ($python_version_full) is too old."
        log_error "Please install Python $required_major.$required_minor or newer."
        log_info "Found Python at: $($python_cmd -c 'import sys; print(sys.executable)')"
        return 1
    else
        log_success "Python $python_version ($python_version_full) is compatible (found at $($python_cmd -c 'import sys; print(sys.executable)'))."
        return 0
    fi
}

# --- Depot Tools Utilities ---

# Function to find the depot_tools directory.
# Checks DEPOT_TOOLS_PATH env var, then common locations relative to project_root.
#
# Arguments:
#   $1: project_root_path - The absolute or relative path to the project's root directory.
#
# Outputs:
#   Prints the absolute path to depot_tools to stdout if found.
#   Returns 0 on success, 1 on error.
find_depot_tools_path() {
    local project_root="$1"
    local depot_tools_path_to_check

    if [ -z "$project_root" ]; then
        log_error "Project root path not provided to find_depot_tools_path."
        return 1
    fi

    # 1. Check DEPOT_TOOLS_PATH environment variable
    if [ -n "$DEPOT_TOOLS_PATH" ]; then
        if [ -d "$DEPOT_TOOLS_PATH" ]; then
            log_info "Using depot_tools from DEPOT_TOOLS_PATH: $DEPOT_TOOLS_PATH"
            echo "$DEPOT_TOOLS_PATH" # Output absolute path
            return 0
        else
            log_error "DEPOT_TOOLS_PATH environment variable is set to '$DEPOT_TOOLS_PATH', but it's not a valid directory."
            # Continue to check other locations, but return 1 if nothing else is found
        fi
    fi

    # 2. Check at $project_root/../depot_tools
    depot_tools_path_to_check=$(cd "$project_root/.." && pwd)/depot_tools
    if [ -d "$depot_tools_path_to_check" ]; then
        log_info "Found depot_tools at: $depot_tools_path_to_check"
        echo "$depot_tools_path_to_check"
        return 0
    fi

    # 3. Check at $project_root/depot_tools
    depot_tools_path_to_check=$(cd "$project_root" && pwd)/depot_tools
     if [ -d "$depot_tools_path_to_check" ]; then
        log_info "Found depot_tools at: $depot_tools_path_to_check"
        echo "$depot_tools_path_to_check"
        return 0
    fi

    log_error "depot_tools not found. Checked:"
    log_error "  - DEPOT_TOOLS_PATH environment variable (if set)"
    log_error "  - $project_root/../depot_tools"
    log_error "  - $project_root/depot_tools"
    log_error "Please ensure depot_tools is installed and accessible, or set DEPOT_TOOLS_PATH."
    return 1
}

# Function to add depot_tools to PATH.
#
# Arguments:
#   $1: depot_tools_directory - The path to the depot_tools directory.
#
# Outputs:
#   Logs information about the PATH modification.
#   Returns 0 on success, 1 on error (e.g., if directory is not provided or doesn't exist).
#   Exports the updated PATH environment variable for the current session.
add_depot_tools_to_path() {
    local depot_tools_dir="$1"
    if [ -z "$depot_tools_dir" ]; then
        log_error "Depot tools directory not provided to add_depot_tools_to_path."
        return 1
    fi
    if [ ! -d "$depot_tools_dir" ]; then
        log_error "Depot tools directory '$depot_tools_dir' does not exist."
        return 1
    fi
    export PATH="$depot_tools_dir:$PATH"
    log_info "Added depot_tools to PATH for this session: $depot_tools_dir"

    # Verify gn and autoninja are available now
    if ! command_exists "gn"; then
        log_warn "'gn' command not found after attempting to add depot_tools to PATH. Ensure depot_tools is correctly installed in '$depot_tools_dir'."
    fi
    if ! command_exists "autoninja"; then
        log_warn "'autoninja' command not found after attempting to add depot_tools to PATH. Ensure depot_tools is correctly installed in '$depot_tools_dir'."
    fi
    return 0
}

log_info "Shared utilities script loaded."
