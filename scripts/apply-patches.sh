#!/bin/bash

# HenSurf Browser - Patch Application Script
set -e

# Source utility functions
SCRIPT_DIR_APPLY_PATCHES=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR_APPLY_PATCHES/utils.sh"

# Define Project Root and log file path (relative to project root)
PROJECT_ROOT=$(cd "$SCRIPT_DIR_APPLY_PATCHES/.." &>/dev/null && pwd)
LOG_FILE="$PROJECT_ROOT/apply-patches.log"
# Clear previous log file
true >"$LOG_FILE"

START_TIME=$(date +%s)
PATCH_FAILURES_LIST=() # Array to keep track of failed patches

# Function to log progress with timing (uses utils.sh _log)
log_progress() {
    local step="$1"
    local current_time; current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    log_info "[PROGRESS] Step $step completed in ${elapsed}s total elapsed" | tee -a "$LOG_FILE"
}

log_info "🔧 Starting HenSurf patch application..." | tee -a "$LOG_FILE"

# Depot Tools Setup
DEPOT_TOOLS_DIR=$(get_depot_tools_dir "$PROJECT_ROOT")
if [ -z "$DEPOT_TOOLS_DIR" ]; then
    log_error "Failed to determine depot_tools directory path. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi
if ! add_depot_tools_to_path "$DEPOT_TOOLS_DIR"; then
    log_error "Failed to add depot_tools to PATH. Exiting." | tee -a "$LOG_FILE"
    # add_depot_tools_to_path already logs details
    exit 1
fi
log_success "✅ depot_tools configured and added to PATH." | tee -a "$LOG_FILE"


# Check for essential commands
if ! command_exists "patch"; then
    log_error "❌ 'patch' command not found. Please install it or ensure it's in your PATH." | tee -a "$LOG_FILE"
    log_error "   On Windows, Git Bash usually includes 'patch'." | tee -a "$LOG_FILE"
    exit 1
fi
log_success "✅ 'patch' command found." | tee -a "$LOG_FILE"

log_info "Working directory: $(pwd)" | tee -a "$LOG_FILE"
OS_TYPE_APPLY=$(get_os_type)

# OS-specific disk space and initial source size logging
if [[ "$OS_TYPE_APPLY" == "windows" ]]; then
    CURRENT_DRIVE_LETTER_APPLY=$(pwd -W | cut -d':' -f1)
    if command_exists "wmic"; then
        AVAILABLE_BYTES_STR_APPLY=$(wmic logicaldisk where "DeviceID='${CURRENT_DRIVE_LETTER_APPLY}:'" get FreeSpace /value | tr -d '\r' | grep FreeSpace | cut -d'=' -f2)
        if [[ -n "$AVAILABLE_BYTES_STR_APPLY" && "$AVAILABLE_BYTES_STR_APPLY" =~ ^[0-9]+$ ]]; then
            AVAILABLE_SPACE_INFO=$(awk -v bytes="$AVAILABLE_BYTES_STR_APPLY" 'BEGIN { printf "%.0f GB", bytes / 1024 / 1024 / 1024 }')
            log_info "Available disk space on drive ${CURRENT_DRIVE_LETTER_APPLY}: $AVAILABLE_SPACE_INFO" | tee -a "$LOG_FILE"
        else
            log_warn "Available disk space on drive ${CURRENT_DRIVE_LETTER_APPLY}: (Could not determine using wmic: '$AVAILABLE_BYTES_STR_APPLY')" | tee -a "$LOG_FILE"
        fi
    else
        log_warn "Available disk space: ('wmic' not found, cannot check on Windows)" | tee -a "$LOG_FILE"
    fi
    if [ -d "$PROJECT_ROOT/src/chromium" ]; then
        log_info "📁 Chromium source directory found at src/chromium. (Size check skipped on Windows for performance)" | tee -a "$LOG_FILE"
    fi
else # Linux/macOS
    log_info "Available disk space: $(df -h . | tail -1 | awk '{print $4}')" | tee -a "$LOG_FILE"
    if [ -d "$PROJECT_ROOT/src/chromium" ]; then
        log_info "📁 Chromium source found, size: $(du -sh $PROJECT_ROOT/src/chromium | cut -f1)" | tee -a "$LOG_FILE"
    fi
fi

# Check if Chromium source exists
CHROMIUM_SRC_DIR="$PROJECT_ROOT/src/chromium"
if [ ! -d "$CHROMIUM_SRC_DIR" ]; then
    log_error "❌ Chromium source not found at $CHROMIUM_SRC_DIR. Please run ./scripts/fetch-chromium.sh first." | tee -a "$LOG_FILE"
    exit 1
fi

safe_cd "$CHROMIUM_SRC_DIR" # Using safe_cd from utils.sh
# log_info message for successful cd is handled by safe_cd itself.

log_info "📋 Starting patch application..." | tee -a "$LOG_FILE"

# Apply main AI removal patch
log_info "🤖 Applying 'remove-ai-features.patch'..." | tee -a "$LOG_FILE"
# Attempt to apply the patch.
if patch -p1 --forward < "$PROJECT_ROOT/src/hensurf/patches/remove-ai-features.patch" 2>&1 | tee -a "$LOG_FILE"; then
    log_success "✅ 'remove-ai-features.patch' applied successfully." | tee -a "$LOG_FILE"
else
    # Store exit code of the patch command
    PATCH_STATUS=$?
    if [ $PATCH_STATUS -eq 1 ]; then # Exit code 1 typically means conflicts or already applied
        log_warn "⚠️ 'remove-ai-features.patch' failed to apply cleanly (exit code $PATCH_STATUS). It might be partially applied, already applied, or have conflicts. Continuing script." | tee -a "$LOG_FILE"
        # Optionally, try to reverse it if it's partially applied and that's desired.
        # For now, we just warn and continue.
        # patch -p1 -R < "$PROJECT_ROOT/patches/remove-ai-features.patch" > /dev/null 2>&1 || true
        PATCH_FAILURES_LIST+=("remove-ai-features.patch (conflicts/already applied)")
    else # Other non-zero exit codes
        log_warn "❌ 'remove-ai-features.patch' failed with unexpected exit code $PATCH_STATUS. Continuing script." | tee -a "$LOG_FILE"
        PATCH_FAILURES_LIST+=("remove-ai-features.patch (error code $PATCH_STATUS)")
    fi
fi
log_progress "AI_REMOVAL"

log_info "ℹ️ Bloatware removal via patch is currently disabled. Feature is controlled by HENSURF_ENABLE_BLOATWARE GN arg." | tee -a "$LOG_FILE"

# Apply logo integration patch
log_info "🎨 Applying 'integrate-logo.patch'..." | tee -a "$LOG_FILE"
if patch -p1 --forward < "$PROJECT_ROOT/src/hensurf/patches/integrate-logo.patch" 2>&1 | tee -a "$LOG_FILE"; then
    log_success "✅ 'integrate-logo.patch' applied successfully." | tee -a "$LOG_FILE"
else
    PATCH_STATUS=$?
    if [ $PATCH_STATUS -eq 1 ]; then
        log_warn "⚠️ 'integrate-logo.patch' failed to apply cleanly (exit code $PATCH_STATUS). It might be partially applied, already applied, or have conflicts. Continuing script." | tee -a "$LOG_FILE"
        PATCH_FAILURES_LIST+=("integrate-logo.patch (conflicts/already applied)")
    else
        log_warn "❌ 'integrate-logo.patch' failed with unexpected exit code $PATCH_STATUS. Continuing script." | tee -a "$LOG_FILE"
        PATCH_FAILURES_LIST+=("integrate-logo.patch (error code $PATCH_STATUS)")
    fi
fi
log_progress "LOGO_INTEGRATION"

# Create custom build configuration
# This is done before setup-logo.sh as setup-logo.sh might place files
# referenced by the build configuration (e.g. if args.gn refers to specific theme files).
# However, the BRANDING file copy itself has been moved to setup-logo.sh.
log_info "⚙️ Setting up build configuration..." | tee -a "$LOG_FILE"
log_info "   Creating directory out/HenSurf for build configuration (if it doesn't exist)..." | tee -a "$LOG_FILE"
mkdir -p out/HenSurf # Default build dir, can be overridden by HENSURF_OUTPUT_DIR in build.sh
log_info "   Copying $PROJECT_ROOT/src/hensurf/config/hensurf.gn to out/HenSurf/args.gn..." | tee -a "$LOG_FILE"
# This args.gn will be used by `gn gen out/HenSurf` or if HENSURF_OUTPUT_DIR is not set.
# If HENSURF_OUTPUT_DIR is set in build.sh, that script will handle its own args.gn.
cp "$PROJECT_ROOT/src/hensurf/config/hensurf.gn" out/HenSurf/args.gn
log_success "✅ Default build configuration created at out/HenSurf/args.gn." | tee -a "$LOG_FILE"
log_progress "BUILD_CONFIG"

# Modify default search engine
log_info "🔍 Setting DuckDuckGo as default search engine..." | tee -a "$LOG_FILE"
log_info "   Creating components/search_engines/hensurf_engines.cc..." | tee -a "$LOG_FILE"
cat > components/search_engines/hensurf_engines.cc << 'EOF'
// HenSurf custom search engines
#include "components/search_engines/search_engines_pref_names.h"
#include "components/search_engines/template_url_prepopulate_data.h"

namespace TemplateURLPrepopulateData {

// DuckDuckGo search engine for HenSurf
const PrepopulatedEngine duckduckgo = {
  L"DuckDuckGo",
  L"duckduckgo.com",
  "https://duckduckgo.com/favicon.ico",
  "https://duckduckgo.com/?q={searchTerms}",
  nullptr,  // No suggestions URL for privacy
  nullptr,
  nullptr,
  nullptr,
  nullptr,
  nullptr,
  nullptr,
  SEARCH_ENGINE_DUCKDUCKGO,
  1,  // ID
};

}  // namespace TemplateURLPrepopulateData
EOF
log_success "✅ Created components/search_engines/hensurf_engines.cc." | tee -a "$LOG_FILE"
log_progress "SEARCH_ENGINE"

# Disable Google API keys
log_info "🔑 Disabling Google API integration..." | tee -a "$LOG_FILE"
log_info "   Creating google_apis/google_api_keys.cc to disable Google API calls..." | tee -a "$LOG_FILE"
cat > google_apis/google_api_keys.cc << 'EOF'
// HenSurf - Disable Google API keys
#include "google_apis/google_api_keys.h"

namespace google_apis {

std::string GetAPIKey() { return std::string(); }
std::string GetOAuth2ClientID(OAuth2Client client) { return std::string(); }
std::string GetOAuth2ClientSecret(OAuth2Client client) { return std::string(); }
bool HasAPIKeyConfigured() { return false; }
bool HasOAuthConfigured() { return false; }

}  // namespace google_apis
EOF
log_success "✅ Created google_apis/google_api_keys.cc." | tee -a "$LOG_FILE"
log_progress "API_DISABLE"

# Remove promotional content
log_info "📢 Removing promotional content..." | tee -a "$LOG_FILE"
log_info "   Searching for and removing promo files in chrome/browser/ui..." | tee -a "$LOG_FILE"
find chrome/browser/ui -name "*promo*" -type f -print -exec rm -f {} \; 2>/dev/null || true
log_info "   Searching for and removing welcome files in chrome/browser/ui..." | tee -a "$LOG_FILE"
find chrome/browser/ui -name "*welcome*" -type f -print -exec rm -f {} \; 2>/dev/null || true
log_success "✅ Promotional content removal attempt finished." | tee -a "$LOG_FILE"
log_progress "PROMO_REMOVAL"

# Disable crash reporting by default
log_info "💥 Disabling crash reporting..." | tee -a "$LOG_FILE"
log_info "   Creating components/crash/core/common/crash_key.cc to disable crash reporting..." | tee -a "$LOG_FILE"
cat > components/crash/core/common/crash_key.cc << 'EOF'
// HenSurf - Disable crash reporting
#include "components/crash/core/common/crash_key.h"

namespace crash_keys {
void SetCrashKeyValue(const std::string& key, const std::string& value) {}
void ClearCrashKey(const std::string& key) {}
void SetCrashKeyToInt(const std::string& key, int value) {}
}  // namespace crash_keys
EOF
log_success "✅ Created components/crash/core/common/crash_key.cc." | tee -a "$LOG_FILE"
log_progress "CRASH_DISABLE"

# Update version info
log_info "📝 Updating version information in chrome/VERSION..." | tee -a "$LOG_FILE"
# Using more specific sed commands to avoid accidental replacements.
log_info "   Running: sed -i.bak 's|^PRODUCT_FULLNAME=Chromium$|PRODUCT_FULLNAME=HenSurf Browser|' chrome/VERSION" | tee -a "$LOG_FILE"
sed -i.bak 's|^PRODUCT_FULLNAME=Chromium$|PRODUCT_FULLNAME=HenSurf Browser|' chrome/VERSION
log_info "   Running: sed -i.bak 's|^PRODUCT_SHORTNAME=Chromium$|PRODUCT_SHORTNAME=HenSurf|' chrome/VERSION" | tee -a "$LOG_FILE"
sed -i.bak 's|^PRODUCT_SHORTNAME=Chromium$|PRODUCT_SHORTNAME=HenSurf|' chrome/VERSION
log_info "   Removing backup file chrome/VERSION.bak..." | tee -a "$LOG_FILE"
rm -f chrome/VERSION.bak
log_success "✅ Version information updated." | tee -a "$LOG_FILE"
log_progress "VERSION_UPDATE"

# Create HenSurf-specific user agent
log_info "🌐 Customizing user agent..." | tee -a "$LOG_FILE"
log_info "   Creating 'components/version_info/hensurf_version_info.cc' for custom user agent..." | tee -a "$LOG_FILE"
cat > components/version_info/hensurf_version_info.cc << 'EOF'
#include "components/version_info/version_info.h"

namespace version_info {

std::string GetProductName() {
  return "HenSurf";
}

std::string GetProductNameAndVersionForUserAgent() {
  return "HenSurf/1.0";
}

}  // namespace version_info
EOF
log_success "✅ Created components/version_info/hensurf_version_info.cc." | tee -a "$LOG_FILE"
log_progress "USER_AGENT"

# Call setup-logo.sh to place all physical icon and branding files.
# This should be done after patches are applied, as patches might affect directory structures
# or build files that setup-logo.sh relies on or that reference assets it places.
log_info "🎨 Executing 'scripts/setup-logo.sh' to place icon and branding files..." | tee -a "$LOG_FILE"
SETUP_LOGO_SCRIPT="$PROJECT_ROOT/scripts/setup-logo.sh"

if [ -f "$SETUP_LOGO_SCRIPT" ]; then
    # Ensure it's executable
    chmod +x "$SETUP_LOGO_SCRIPT"
    # Execute setup-logo.sh. It cds into src/chromium itself.
    # We are already in src/chromium, but setup-logo.sh is written to be callable from project root too.
    # To ensure it behaves as expected when called from apply-patches.sh (already in src/chromium),
    # it's fine to call it directly. It uses PROJECT_ROOT for paths to branding assets.
    if "$SETUP_LOGO_SCRIPT" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "✅ 'scripts/setup-logo.sh' executed successfully." | tee -a "$LOG_FILE"
    else
        log_warn "⚠️ 'scripts/setup-logo.sh' execution reported errors. Check log." | tee -a "$LOG_FILE"
        # Decide if this is a fatal error for apply-patches.sh or not.
        # For now, log as warning and continue.
        PATCH_FAILURES_LIST+=("setup-logo.sh execution")
    fi
else
    log_error "❌ Critical script 'scripts/setup-logo.sh' not found at '$SETUP_LOGO_SCRIPT'. Cannot proceed with logo/branding setup." | tee -a "$LOG_FILE"
    # This is likely a fatal error for the branding goals.
    PATCH_FAILURES_LIST+=("setup-logo.sh not found")
    # exit 1; # Or continue if some patching is still valuable. For now, continue and report.
fi
log_progress "LOGO_FILE_SETUP"


# Final summary
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

log_info "" | tee -a "$LOG_FILE" # Spacer
if [ ${#PATCH_FAILURES_LIST[@]} -eq 0 ]; then
    log_success "✅ All patches and customization steps completed successfully in ${TOTAL_TIME} seconds!" | tee -a "$LOG_FILE"
else
    log_warn "⚠️ Some patches or steps encountered issues. Total time: ${TOTAL_TIME} seconds." | tee -a "$LOG_FILE"
    log_warn "   The following patches reported failures or issues:" | tee -a "$LOG_FILE"
    for failure in "${PATCH_FAILURES_LIST[@]}"; do
        log_warn "     - $failure" | tee -a "$LOG_FILE"
    done
    log_warn "   Please review the log file '$LOG_FILE' for details." | tee -a "$LOG_FILE"
    log_warn "   The script continued where possible, but the build may not be as expected." | tee -a "$LOG_FILE"
fi


if [[ "$OS_TYPE_APPLY" == "windows" ]]; then
    log_info "📊 Final disk usage of src/chromium: (Size check skipped on Windows for performance)." | tee -a "$LOG_FILE"
else
    log_info "📊 Final disk usage of src/chromium: $(du -sh . | cut -f1)." | tee -a "$LOG_FILE"
fi

log_info "" # Use log_info for consistent formatting, tee not needed for final stdout block
log_info "HenSurf Browser - Customization Summary:"
log_info "  - AI Features: Attempted removal (check warnings if any)"
log_info "  - Logo Integration: Attempted (check warnings if any)"
log_info "  - Branding Files: Copied"
log_info "  - Build Configuration: Default 'args.gn' created/updated for 'out/HenSurf'"
log_info "  - Default Search Engine: Set to DuckDuckGo (via C++ override)"
log_info "  - Google API Keys: Disabled (via C++ override)"
log_info "  - Promotional Content: Attempted removal"
log_info "  - Crash Reporting: Disabled (via C++ override)"
log_info "  - Version Info: Updated to 'HenSurf Browser' / 'HenSurf'"
log_info "  - User Agent: Customized (via C++ override)"
log_info "  - Logo Setup Script: Executed (if found)"
log_info ""
if [ ${#PATCH_FAILURES_LIST[@]} -ne 0 ]; then
    log_warn "🔴 IMPORTANT: One or more patches failed to apply cleanly. Review messages above and the log file."
fi
log_info "📋 Detailed log saved to: $LOG_FILE"
log_info "⏱️ Total time for patch script: ${TOTAL_TIME} seconds."
log_info "Next step: Run ./scripts/build.sh to build HenSurf Browser."