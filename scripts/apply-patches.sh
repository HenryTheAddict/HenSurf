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
    if [ -d "chromium/src" ]; then
        log_info "📁 Chromium source directory found at chromium/src. (Size check skipped on Windows for performance)" | tee -a "$LOG_FILE"
    fi
else # Linux/macOS
    log_info "Available disk space: $(df -h . | tail -1 | awk '{print $4}')" | tee -a "$LOG_FILE"
    if [ -d "chromium/src" ]; then
        log_info "📁 Chromium source found, size: $(du -sh chromium/src | cut -f1)" | tee -a "$LOG_FILE"
    fi
fi

# Check if Chromium source exists
CHROMIUM_SRC_DIR="$PROJECT_ROOT/chromium/src"
if [ ! -d "$CHROMIUM_SRC_DIR" ]; then
    log_error "❌ Chromium source not found at $CHROMIUM_SRC_DIR. Please run ./scripts/fetch-chromium.sh first." | tee -a "$LOG_FILE"
    exit 1
fi

cd "$CHROMIUM_SRC_DIR"
log_info "📂 Changed to chromium/src directory ($(pwd))" | tee -a "$LOG_FILE"

log_info "📋 Starting patch application..." | tee -a "$LOG_FILE"

# Apply main AI removal patch
log_info "🤖 Starting AI features removal..." | tee -a "$LOG_FILE"
if patch -p1 --dry-run < "$PROJECT_ROOT/patches/remove-ai-features.patch" > /dev/null 2>&1; then
    log_info "[PATCH] Applying AI features removal patch..." | tee -a "$LOG_FILE"
    if patch -p1 < "$PROJECT_ROOT/patches/remove-ai-features.patch" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "✅ AI features patch applied successfully" | tee -a "$LOG_FILE"
    else
        log_error "❌ AI features patch failed" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    log_warn "⚠️ AI features patch may already be applied or conflicts exist" | tee -a "$LOG_FILE"
fi
log_progress "AI_REMOVAL"

log_info "ℹ️ Bloatware removal via patch is currently disabled. Feature is controlled by HENSURF_ENABLE_BLOATWARE GN arg." | tee -a "$LOG_FILE"

# Apply logo integration patch
log_info "🎨 Starting logo integration..." | tee -a "$LOG_FILE"
log_info "[PATCH] Reading patch: $PROJECT_ROOT/patches/integrate-logo.patch" | tee -a "$LOG_FILE"
if patch -p1 < "$PROJECT_ROOT/patches/integrate-logo.patch" 2>&1 | tee -a "$LOG_FILE"; then
    log_success "✅ Logo integration patch applied successfully" | tee -a "$LOG_FILE"
else
    log_error "❌ Failed to apply logo integration patch" | tee -a "$LOG_FILE"
    exit 1
fi
log_progress "LOGO_INTEGRATION"

# Copy branding files
log_info "🏷️ Applying HenSurf branding..." | tee -a "$LOG_FILE"
log_info "Creating directory chrome/app/theme/hensurf for branding..." | tee -a "$LOG_FILE"
mkdir -p chrome/app/theme/hensurf
log_info "Copying $PROJECT_ROOT/branding/BRANDING to chrome/app/theme/hensurf/BRANDING..." | tee -a "$LOG_FILE"
cp "$PROJECT_ROOT/branding/BRANDING" chrome/app/theme/hensurf/
log_success "✅ Branding files copied" | tee -a "$LOG_FILE"
log_progress "BRANDING"

# Create custom build configuration
log_info "⚙️ Setting up build configuration..." | tee -a "$LOG_FILE"
log_info "Creating directory out/HenSurf for build configuration..." | tee -a "$LOG_FILE"
mkdir -p out/HenSurf
log_info "Copying $PROJECT_ROOT/config/hensurf.gn to out/HenSurf/args.gn..." | tee -a "$LOG_FILE"
cp "$PROJECT_ROOT/config/hensurf.gn" out/HenSurf/args.gn
log_success "✅ Build configuration created" | tee -a "$LOG_FILE"
log_progress "BUILD_CONFIG"

# Modify default search engine
log_info "🔍 Setting DuckDuckGo as default search engine..." | tee -a "$LOG_FILE"
log_info "Creating components/search_engines/hensurf_engines.cc..." | tee -a "$LOG_FILE"
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
log_success "✅ Created components/search_engines/hensurf_engines.cc" | tee -a "$LOG_FILE"
log_progress "SEARCH_ENGINE"

# Disable Google API keys
log_info "🔑 Disabling Google API integration..." | tee -a "$LOG_FILE"
log_info "Creating google_apis/google_api_keys.cc to disable Google API calls..." | tee -a "$LOG_FILE"
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
log_success "✅ Created google_apis/google_api_keys.cc" | tee -a "$LOG_FILE"
log_progress "API_DISABLE"

# Remove promotional content
log_info "📢 Removing promotional content..." | tee -a "$LOG_FILE"
log_info "Searching for and removing promo files in chrome/browser/ui..." | tee -a "$LOG_FILE"
find chrome/browser/ui -name "*promo*" -type f -print -exec rm -f {} \; 2>/dev/null || true
log_info "Searching for and removing welcome files in chrome/browser/ui..." | tee -a "$LOG_FILE"
find chrome/browser/ui -name "*welcome*" -type f -print -exec rm -f {} \; 2>/dev/null || true
log_success "✅ Promotional content removal attempt finished" | tee -a "$LOG_FILE"
log_progress "PROMO_REMOVAL"

# Disable crash reporting by default
log_info "💥 Disabling crash reporting..." | tee -a "$LOG_FILE"
log_info "Creating components/crash/core/common/crash_key.cc to disable crash reporting..." | tee -a "$LOG_FILE"
cat > components/crash/core/common/crash_key.cc << 'EOF'
// HenSurf - Disable crash reporting
#include "components/crash/core/common/crash_key.h"

namespace crash_keys {
void SetCrashKeyValue(const std::string& key, const std::string& value) {}
void ClearCrashKey(const std::string& key) {}
void SetCrashKeyToInt(const std::string& key, int value) {}
}  // namespace crash_keys
EOF
log_success "✅ Created components/crash/core/common/crash_key.cc" | tee -a "$LOG_FILE"
log_progress "CRASH_DISABLE"

# Update version info
log_info "📝 Updating version information in chrome/VERSION..." | tee -a "$LOG_FILE"
# Log actual sed commands for clarity, though output is suppressed by tee for these.
log_info "Running: sed -i.bak 's/PRODUCT_FULLNAME=Chromium/PRODUCT_FULLNAME=HenSurf Browser/' chrome/VERSION"
sed -i.bak 's/PRODUCT_FULLNAME=Chromium/PRODUCT_FULLNAME=HenSurf Browser/' chrome/VERSION
log_info "Running: sed -i.bak 's/PRODUCT_SHORTNAME=Chromium/PRODUCT_SHORTNAME=HenSurf/' chrome/VERSION"
sed -i.bak 's/PRODUCT_SHORTNAME=Chromium/PRODUCT_SHORTNAME=HenSurf/' chrome/VERSION
log_info "Removing backup file chrome/VERSION.bak..." | tee -a "$LOG_FILE"
rm -f chrome/VERSION.bak
log_success "✅ Version information updated" | tee -a "$LOG_FILE"
log_progress "VERSION_UPDATE"

# Create HenSurf-specific user agent
log_info "🌐 Customizing user agent..." | tee -a "$LOG_FILE"
log_info "Creating components/version_info/hensurf_version_info.cc for custom user agent..." | tee -a "$LOG_FILE"
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
log_success "✅ Created components/version_info/hensurf_version_info.cc" | tee -a "$LOG_FILE"
log_progress "USER_AGENT"

log_info "🎨 Setting up HenSurf logo and icons using setup-logo.sh..." | tee -a "$LOG_FILE"
SETUP_LOGO_SCRIPT="$PROJECT_ROOT/scripts/setup-logo.sh"
if [ -f "$SETUP_LOGO_SCRIPT" ]; then
    log_info "[SCRIPT] Executing setup-logo.sh" | tee -a "$LOG_FILE"
    # Ensure it's executable
    chmod +x "$SETUP_LOGO_SCRIPT"
    # Execute from project root context or ensure script handles relative paths correctly
    (cd "$PROJECT_ROOT" && "$SETUP_LOGO_SCRIPT" ) 2>&1 | tee -a "$LOG_FILE"
    log_success "✅ Logo setup completed" | tee -a "$LOG_FILE"
else
    log_warn "⚠️ setup-logo.sh not found at $SETUP_LOGO_SCRIPT, skipping logo setup" | tee -a "$LOG_FILE"
fi
log_progress "LOGO_SETUP"

# Final summary
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
log_success "✅ All patches applied successfully in ${TOTAL_TIME} seconds!" | tee -a "$LOG_FILE"

if [[ "$OS_TYPE_APPLY" == "windows" ]]; then
    log_info "📊 Final disk usage of chromium/src: (Size check skipped on Windows for performance)" | tee -a "$LOG_FILE"
else
    log_info "📊 Final disk usage of chromium/src: $(du -sh . | cut -f1)" | tee -a "$LOG_FILE"
fi

echo ""
log_info "HenSurf customizations:"
log_info "  ✅ AI features removed"
log_info "  ✅ Google services disabled"
log_info "  ✅ DuckDuckGo set as default search"
log_info "  ✅ Crash reporting disabled"
log_info "  ✅ Promotional content removed"
log_info "  ✅ Custom branding applied"
echo ""
log_info "📋 Detailed log saved to: $LOG_FILE"
log_info "⏱️ Total time: ${TOTAL_TIME} seconds"
log_info "Next step: Run ./scripts/build.sh to build HenSurf"