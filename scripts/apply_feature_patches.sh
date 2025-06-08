#!/bin/bash

# HenSurf Browser - Feature Patch Management Script
# This script applies or unapplies specific feature patches to the Chromium source code.
# It is intended for toggling discrete features during development or experimentation.
# Patches are expected to be in the 'src/hensurf/patches/' directory relative to the project root.

set -e

# Source utility functions
SCRIPT_DIR_FEATURE_PATCH=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR_FEATURE_PATCH/utils.sh"

# Function to display usage instructions
usage() {
  log_error "Usage: $0 <apply|unapply> <feature_name>"
  log_error "Example: $0 apply remove-some-feature"
  log_error "  'feature_name' corresponds to 'src/hensurf/patches/feature_name.patch'"
  exit 1
}

# Check for correct number of arguments
if [ "$#" -ne 2 ]; then
  usage
fi

ACTION="$1"
FEATURE_NAME="$2"
# Assume this script is run from the project root. Patches are in a subdirectory.
PATCH_FILE="src/hensurf/patches/${FEATURE_NAME}.patch"

log_info "🔧 Attempting to $ACTION patch for feature '$FEATURE_NAME' using '$PATCH_FILE'..."

# Check if patch file exists
if [ ! -f "$PATCH_FILE" ]; then
  log_error "❌ Patch file not found: '$PATCH_FILE'"
  log_error "   Please ensure the feature name is correct and the patch file exists."
  exit 1
fi

# Determine the Git apply options
# --reject: Creates .rej files for failed hunks instead of failing the whole operation.
# --ignore-whitespace: Ignores whitespace differences.
# --unidiff-zero: Ensures patch context is zero, useful for patches generated with `git diff --patience`.
GIT_APPLY_OPTS="--reject --ignore-whitespace --unidiff-zero"

# Apply or unapply the patch
case "$ACTION" in
  apply)
    log_info "   Applying patch: $PATCH_FILE"
    if git apply $GIT_APPLY_OPTS "$PATCH_FILE"; then
      log_success "✅ Patch '$PATCH_FILE' applied successfully."
    else
      log_error "❌ Error applying patch '$PATCH_FILE'."
      log_error "   Review any '.rej' files created for conflict details."
      log_error "   You may need to resolve conflicts manually or update the patch file."
      exit 1 # Exit with error if applying fails.
    fi
    ;;
  unapply)
    log_info "   Unapplying patch: $PATCH_FILE"
    if git apply --reverse $GIT_APPLY_OPTS "$PATCH_FILE"; then
      log_success "✅ Patch '$PATCH_FILE' unapplied successfully."
    else
      log_error "❌ Error unapplying patch '$PATCH_FILE'."
      log_error "   Review any '.rej' files created for conflict details."
      log_error "   This might happen if the code has changed since the patch was applied."
      exit 1 # Exit with error if unapplying fails.
    fi
    ;;
  *)
    usage # Show usage if action is not 'apply' or 'unapply'
    ;;
esac

log_info "🏁 Feature patch management for '$FEATURE_NAME' completed."
exit 0
