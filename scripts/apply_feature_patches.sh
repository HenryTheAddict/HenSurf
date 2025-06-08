#!/bin/bash

# Script to apply or unapply feature patches

# Function to display usage
usage() {
  echo "Usage: $0 <apply|unapply> <feature_name>"
  echo "Example: $0 apply remove-bloatware"
  exit 1
}

# Check for correct number of arguments
if [ "$#" -ne 2 ]; then
  usage
fi

ACTION="$1"
FEATURE_NAME="$2"
PATCH_FILE="patches/${FEATURE_NAME}.patch"

# Check if patch file exists
if [ ! -f "$PATCH_FILE" ]; then
  echo "Error: Patch file not found: $PATCH_FILE"
  exit 1
fi

# Apply or unapply the patch
case "$ACTION" in
  apply)
    echo "Applying patch: $PATCH_FILE"
    if git apply --reject --ignore-whitespace --unidiff-zero "$PATCH_FILE"; then
      echo "Patch applied successfully."
    else
      echo "Error applying patch. Check for .rej files for conflicts."
      exit 1
    fi
    ;;
  unapply)
    echo "Unapplying patch: $PATCH_FILE"
    if git apply --reverse --reject --ignore-whitespace --unidiff-zero "$PATCH_FILE"; then
      echo "Patch unapplied successfully."
    else
      echo "Error unapplying patch. Check for .rej files for conflicts."
      exit 1
    fi
    ;;
  *)
    usage
    ;;
esac

exit 0
