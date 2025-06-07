#!/bin/bash

# HenSurf Browser - Patch Application Script with Enhanced Logging
set -e

# Enhanced logging setup
LOG_FILE="../apply-patches.log"
START_TIME=$(date +%s)

# Function to log with timestamp
log_with_time() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Function to log progress with timing
log_progress() {
    local step="$1"
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    log_with_time "[PROGRESS] Step $step completed in ${elapsed}s total elapsed"
}

log_with_time "🔧 Starting HenSurf patch application..."
log_with_time "Working directory: $(pwd)"
log_with_time "Available disk space: $(df -h . | tail -1 | awk '{print $4}')"

# Check if Chromium source exists
if [ ! -d "chromium/src" ]; then
    log_with_time "❌ Chromium source not found. Please run ./scripts/fetch-chromium.sh first."
    exit 1
fi

log_with_time "📁 Chromium source found, size: $(du -sh chromium/src | cut -f1)"
cd chromium/src
log_with_time "📂 Changed to chromium/src directory"

log_with_time "📋 Starting patch application..."

# Apply main AI removal patch
log_with_time "🤖 Starting AI features removal..."
if patch -p1 --dry-run < ../../patches/remove-ai-features.patch > /dev/null 2>&1; then
    log_with_time "[PATCH] Applying AI features removal patch..."
    if patch -p1 < ../../patches/remove-ai-features.patch 2>&1 | tee -a "$LOG_FILE"; then
        log_with_time "✅ AI features patch applied successfully"
    else
        log_with_time "❌ AI features patch failed"
        exit 1
    fi
else
    log_with_time "⚠️ AI features patch may already be applied or conflicts exist"
fi
log_progress "AI_REMOVAL"

# Apply bloatware removal patch
log_with_time "🗑️ Starting bloatware removal..."
log_file_op "Reading patch" "../../patches/remove-bloatware.patch"
if patch -p1 < ../../patches/remove-bloatware.patch 2>&1 | tee -a "$LOG_FILE"; then
    log_with_time "✅ Bloatware removal patch applied successfully"
else
    log_with_time "❌ Failed to apply bloatware removal patch"
    exit 1
fi
log_progress "BLOATWARE_REMOVAL"

# Apply logo integration patch
log_with_time "🎨 Starting logo integration..."
log_file_op "Reading patch" "../../patches/integrate-logo.patch"
if patch -p1 < ../../patches/integrate-logo.patch 2>&1 | tee -a "$LOG_FILE"; then
    log_with_time "✅ Logo integration patch applied successfully"
else
    log_with_time "❌ Failed to apply logo integration patch"
    exit 1
fi
log_progress "LOGO_INTEGRATION"

# Copy branding files
log_with_time "🏷️ Applying HenSurf branding..."
mkdir -p chrome/app/theme/hensurf
log_file_op "Creating directory" "chrome/app/theme/hensurf"
cp ../../branding/BRANDING chrome/app/theme/hensurf/
log_file_op "Copied" "chrome/app/theme/hensurf/BRANDING"
log_with_time "✅ Branding files copied"
log_progress "BRANDING"

# Create custom build configuration
log_with_time "⚙️ Setting up build configuration..."
mkdir -p out/HenSurf
log_file_op "Creating directory" "out/HenSurf"
cp ../../config/hensurf.gn out/HenSurf/args.gn
log_file_op "Copied" "out/HenSurf/args.gn"
log_with_time "✅ Build configuration created"
log_progress "BUILD_CONFIG"

# Modify default search engine
log_with_time "🔍 Setting DuckDuckGo as default search engine..."
log_with_time "[FILE] Creating components/search_engines/hensurf_engines.cc"
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
log_file_op "Created" "components/search_engines/hensurf_engines.cc"
log_progress "SEARCH_ENGINE"

# Disable Google API keys
log_with_time "🔑 Disabling Google API integration..."
log_with_time "[FILE] Creating google_apis/google_api_keys.cc"
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
log_file_op "Created" "google_apis/google_api_keys.cc"
log_progress "API_DISABLE"

# Remove promotional content
log_with_time "📢 Removing promotional content..."
log_with_time "[CLEANUP] Searching for promo files in chrome/browser/ui..."
find chrome/browser/ui -name "*promo*" -type f -exec rm -f {} \; 2>/dev/null || true
log_with_time "[CLEANUP] Searching for welcome files in chrome/browser/ui..."
find chrome/browser/ui -name "*welcome*" -type f -exec rm -f {} \; 2>/dev/null || true
log_with_time "✅ Promotional content removed"
log_progress "PROMO_REMOVAL"

# Disable crash reporting by default
log_with_time "💥 Disabling crash reporting..."
log_with_time "[FILE] Creating components/crash/core/common/crash_key.cc"
cat > components/crash/core/common/crash_key.cc << 'EOF'
// HenSurf - Disable crash reporting
#include "components/crash/core/common/crash_key.h"

namespace crash_keys {
void SetCrashKeyValue(const std::string& key, const std::string& value) {}
void ClearCrashKey(const std::string& key) {}
void SetCrashKeyToInt(const std::string& key, int value) {}
}  // namespace crash_keys
EOF
log_file_op "Created" "components/crash/core/common/crash_key.cc"
log_progress "CRASH_DISABLE"

# Update version info
log_with_time "📝 Updating version information..."
log_file_op "Modifying" "chrome/VERSION"
sed -i.bak 's/PRODUCT_FULLNAME=Chromium/PRODUCT_FULLNAME=HenSurf Browser/' chrome/VERSION
sed -i.bak 's/PRODUCT_SHORTNAME=Chromium/PRODUCT_SHORTNAME=HenSurf/' chrome/VERSION
log_with_time "✅ Version information updated"
log_progress "VERSION_UPDATE"

# Create HenSurf-specific user agent
log_with_time "🌐 Customizing user agent..."
log_with_time "[FILE] Creating components/version_info/hensurf_version_info.cc"
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
log_file_op "Created" "components/version_info/hensurf_version_info.cc"
log_progress "USER_AGENT"

log_with_time "🎨 Setting up HenSurf logo and icons..."
if [ -f "../../scripts/setup-logo.sh" ]; then
    log_with_time "[SCRIPT] Executing setup-logo.sh"
    "../../scripts/setup-logo.sh" 2>&1 | tee -a "$LOG_FILE"
    log_with_time "✅ Logo setup completed"
else
    log_with_time "⚠️ setup-logo.sh not found, skipping logo setup"
fi
log_progress "LOGO_SETUP"

# Final summary
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
log_with_time "✅ All patches applied successfully in ${TOTAL_TIME} seconds!"
log_with_time "📊 Final disk usage: $(du -sh . | cut -f1)"

echo ""
echo "HenSurf customizations:"
echo "  ✅ AI features removed"
echo "  ✅ Google services disabled"
echo "  ✅ DuckDuckGo set as default search"
echo "  ✅ Crash reporting disabled"
echo "  ✅ Promotional content removed"
echo "  ✅ Custom branding applied"
echo ""
echo "📋 Detailed log saved to: $LOG_FILE"
echo "⏱️ Total time: ${TOTAL_TIME} seconds"
echo "Next step: Run ./scripts/build.sh to build HenSurf"