#!/bin/bash

# HenSurf Browser - Shared Utility Script

# --- Logging Utilities ---

# Function to log with a timestamp and level
_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

log_info() {
    _log "INFO" "$@"
}

log_warn() {
    _log "WARN" "$@"
}

log_error() {
    _log "ERROR" "$@"
}

log_success() {
    _log "SUCCESS" "$@"
}

# --- OS Detection ---

# Function to get current OS type
# Returns "macos", "linux", "windows", or "unknown"
get_os_type() {
    case "$OSTYPE" in
        darwin*) echo "macos" ;;
        linux-gnu*) echo "linux" ;;
        cygwin*|msys*|win32*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# --- Command Utilities ---

# Function to check if a command exists
# Usage: command_exists "command_name"
command_exists() {
    command -v "$1" &> /dev/null
}

# --- Python Utilities ---

# Function to check Python version
# Usage: check_python_version "min_major" "min_minor" "python_executable_name (optional)"
# Returns 0 if compatible, 1 otherwise. Logs details.
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
    python_version_full=$($python_cmd --version 2>&1)
    if [[ $? -ne 0 ]]; then
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

# Function to get the expected depot_tools directory path
# It assumes depot_tools is cloned adjacent to the project root.
# Usage: get_depot_tools_dir "project_root_path"
get_depot_tools_dir() {
    local project_root="$1"
    if [ -z "$project_root" ]; then
        log_error "Project root path not provided to get_depot_tools_dir."
        return 1
    fi
    local parent_of_project_root
    parent_of_project_root=$(cd "$project_root/.." &>/dev/null && pwd)
    if [ -z "$parent_of_project_root" ]; then
        log_error "Could not determine parent directory of project root '$project_root'."
        return 1
    fi
    echo "$parent_of_project_root/depot_tools"
    return 0
}

# Function to add depot_tools to PATH
# Usage: add_depot_tools_to_path "depot_tools_directory"
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
