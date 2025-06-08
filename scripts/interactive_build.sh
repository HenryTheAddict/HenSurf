#!/bin/bash

# HenSurf Browser - Interactive Build Script
# This script provides an interactive menu for users to choose common
# build targets for HenSurf, simplifying the process of setting
# environment variables for build.sh.

set -e

# Source utility functions
# shellcheck disable=SC1091
source "$(dirname "$0")/utils.sh"

# Function to determine native CPU architecture for the current host.
# This helps in defaulting the "Native OS" build option correctly.
# Uses get_os_type from utils.sh.
# Outputs: "x64", "arm64", or defaults to "x64".
get_native_cpu_arch() {
  local os_type
  os_type=$(get_os_type)
  if [[ "$os_type" == "mac" ]]; then
    # On macOS, uname -m can return arm64 or x86_64
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
      echo "arm64"
    else
      echo "x64"
    fi
  elif [[ "$os_type" == "linux" ]]; then
    # On Linux, uname -m typically returns x86_64 for x64
    local arch
    arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]]; then
      echo "x64"
    elif [[ "$arch" == "aarch64" ]]; then
      echo "arm64" # Or however you want to represent ARM on Linux
    else
      echo "x64" # Default to x64 if unsure
    fi
  elif [[ "$os_type" == "win" ]];
  then
    # For Windows, CPU_ARCHITECTURE is usually x86 or AMD64
    # We'll assume x64 for simplicity as per requirements
    if [[ "$PROCESSOR_ARCHITECTURE" == "AMD64" ]] || [[ "$PROCESSOR_ARCHITECTURE" == "EM64T" ]]; then
        echo "x64"
    elif [[ "$PROCESSOR_ARCHITECTURE" == "ARM64" ]]; then
        echo "arm64"
    else
        # Default or add more specific checks if necessary
        echo "x64"
    fi
  else
    # Default for unknown OS, or handle error
    echo "x64"
  fi
}

# Function to perform the build
perform_build() {
  log_info "Starting build for OS: $HENSURF_TARGET_OS, CPU: $HENSURF_TARGET_CPU"
  log_info "Output directory: $HENSURF_OUTPUT_DIR"

  export HENSURF_TARGET_OS
  export HENSURF_TARGET_CPU
  export HENSURF_OUTPUT_DIR

  if bash "./scripts/build.sh"; then
    log_success "Build completed successfully for $HENSURF_TARGET_OS-$HENSURF_TARGET_CPU."
  else
    log_error "Build failed for $HENSURF_TARGET_OS-$HENSURF_TARGET_CPU."
    # Optionally, exit here or let the script continue if it's part of "macOS Both"
  fi
}

# Main script execution
log_info "🚀 HenSurf Interactive Build Script Started"

# Get host OS using the function from utils.sh
HOST_OS=$(get_os_type) # This returns "macos", "linux", "windows", or "unknown"
log_info "ℹ️ Detected Host OS: $HOST_OS"

# Display menu using log_action for better visibility
log_info "" # Blank line for spacing
log_action "------------------------------------"
log_action "  HenSurf Browser - Build Target Menu "
log_action "------------------------------------"
log_info "1. Native OS (autodetect architecture)"
log_info "2. Linux (x64)"
log_info "3. Windows (x64)"
log_info "4. macOS (Intel x64)"
log_info "5. macOS (ARM64)"
log_info "6. macOS (Both Intel x64 and ARM64)"
log_info "7. Exit"
log_info "------------------------------------"
log_info ""

read -r -p "Enter your choice [1-7]: " choice
echo # Add a newline after user input for cleaner logs

case "$choice" in
  1)
    log_info "Selected: Native OS"
    HENSURF_TARGET_OS="$HOST_OS"
    HENSURF_TARGET_CPU=$(get_native_cpu_arch)
    HENSURF_OUTPUT_DIR="out/HenSurf-${HENSURF_TARGET_OS}-${HENSURF_TARGET_CPU}"
    perform_build
    ;;
  2)
    log_info "Selected: Linux (x64)"
    HENSURF_TARGET_OS="linux"
    HENSURF_TARGET_CPU="x64"
    HENSURF_OUTPUT_DIR="out/HenSurf-linux-x64"
    perform_build
    ;;
  3)
    log_info "Selected: Windows (x64)"
    HENSURF_TARGET_OS="win" # Chromium's target_os for Windows
    HENSURF_TARGET_CPU="x64"
    HENSURF_OUTPUT_DIR="out/HenSurf-win-x64"
    perform_build
    ;;
  4)
    log_info "Selected: macOS (Intel x64)"
    HENSURF_TARGET_OS="mac"
    HENSURF_TARGET_CPU="x64"
    HENSURF_OUTPUT_DIR="out/HenSurf-mac-x64"
    perform_build
    ;;
  5)
    log_info "Selected: macOS (ARM64)"
    HENSURF_TARGET_OS="mac"
    HENSURF_TARGET_CPU="arm64"
    HENSURF_OUTPUT_DIR="out/HenSurf-mac-arm64"
    perform_build
    ;;
  6)
    log_info "Selected: macOS (Both Intel x64 and ARM64)"
    NATIVE_MAC_ARCH=$(get_native_cpu_arch) # Check host macOS architecture

    if [[ "$HOST_OS" != "mac" ]]; then # "mac" is the output of get_os_type for macOS
      log_warn "Building for 'macOS Both' is primarily intended to be run on a macOS host for native ARM64/x64 builds."
      log_warn "Cross-compiling might be possible but can be complex depending on setup."
      # Ask user if they want to proceed
      read -r -p "Proceed anyway? (yes/no): " proceed_choice
      echo # Add a newline after user input
      if [[ ! "$proceed_choice" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        log_info "Exiting بناءً على اختيار المستخدم." # Using a non-ASCII char to test UTF-8 handling if it ever gets complex
        exit 0
      fi
    fi

    log_info "ℹ️ Determining build order for macOS Both..."
    # Build native architecture first
    if [[ "$NATIVE_MAC_ARCH" == "arm64" ]]; then
      log_info "Host is ARM64. Building ARM64 first, then x64."
      HENSURF_TARGET_OS="mac"
      HENSURF_TARGET_CPU="arm64"
      HENSURF_OUTPUT_DIR="out/HenSurf-mac-arm64"
      perform_build

      log_info "Building macOS (Intel x64) next..."
      HENSURF_TARGET_OS="mac"
      HENSURF_TARGET_CPU="x64"
      HENSURF_OUTPUT_DIR="out/HenSurf-mac-x64"
      perform_build
    else # Native is x64 or something else (default to x64 first)
      log_info "Host is Intel x64 (or non-ARM64). Building x64 first, then ARM64."
      HENSURF_TARGET_OS="mac"
      HENSURF_TARGET_CPU="x64"
      HENSURF_OUTPUT_DIR="out/HenSurf-mac-x64"
      perform_build

      log_info "Building macOS (ARM64) next..."
      HENSURF_TARGET_OS="mac"
      HENSURF_TARGET_CPU="arm64"
      HENSURF_OUTPUT_DIR="out/HenSurf-mac-arm64"
      perform_build
    fi
    ;;
  7)
    log_info "👋 Exiting."
    ;;
  *)
    log_error "❌ Invalid choice: '$choice'. Please select a number between 1 and 7."
    exit 1
    ;;
esac

log_info "🏁 HenSurf Interactive Build Script Finished."
exit 0 # Exit successfully if a build was attempted (perform_build handles its own exit on failure)
