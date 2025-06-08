#!/bin/bash

# HenSurf Browser - Test Script
# This script runs basic tests to verify HenSurf functionality

set -e

# Source utility functions
SCRIPT_DIR_TEST_HENSURF=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR_TEST_HENSURF/utils.sh"

log_info "🧪 Testing HenSurf Browser..."

# Initialize test counters
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Function to run a test and handle results
# Usage: run_test "Test Name" "command_to_run" "output_file" "expected_keyword_or_condition"
# Note: expected_keyword_or_condition can be a simple string grep, or more complex using "eval" if needed carefully.
# For simplicity, this version will primarily rely on grep for keyword checks.
run_test() {
    local test_name="$1"
    local command_to_run="$2"
    local output_file="$3"
    local success_condition_command="$4" # Command string to evaluate for success
    local result_message=""

    TEST_COUNT=$((TEST_COUNT + 1))
    log_info "🚀 Test $TEST_COUNT: $test_name..."

    # Execute the command
    # The timeout value might need adjustment based on typical page load times.
    # Using eval for command_to_run to allow complex commands with pipes and redirects.
    # Ensure command_to_run is properly quoted and constructed to avoid security issues if it were from external input.
    # Here, it's constructed internally, so it's safer.
    eval "$command_to_run"
    local exit_code=$?

    if [ $exit_code -eq 124 ]; then # Timeout
        log_warn "   ⚠️ Test process for '$test_name' timed out."
        result_message="TIMEOUT"
    elif [ $exit_code -ne 0 ]; then
        log_warn "   ⚠️ Test process for '$test_name' exited with error code $exit_code."
        result_message="PROCESS_ERROR (Code: $exit_code)"
    fi

    # Check success condition
    if [ -z "$result_message" ]; then # If no process error or timeout
        if eval "$success_condition_command"; then
            log_success "   ✅ $test_name passed."
            PASS_COUNT=$((PASS_COUNT + 1))
            return 0
        else
            result_message="VALIDATION_FAILED"
        fi
    fi

    log_error "   ❌ $test_name failed. Reason: $result_message"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    if [ -f "$output_file" ]; then
        log_info "      Output for $test_name (from $output_file):"
        cat "$output_file" # Output HTML/content for debugging
    else
        log_info "      No output file ($output_file) found for $test_name."
    fi
    return 1
}


# Check if HenSurf binary exists
# Assuming HENSURF_BINARY_PATH is relative to PROJECT_ROOT, which is SCRIPT_DIR_TEST_HENSURF/..
PROJECT_ROOT="$(cd "$SCRIPT_DIR_TEST_HENSURF/.." && pwd)"
HENSURF_BINARY_PATH="$PROJECT_ROOT/src/chromium/out/HenSurf/chrome"

if [ ! -f "$HENSURF_BINARY_PATH" ]; then
    log_error "❌ HenSurf binary not found at '$HENSURF_BINARY_PATH'. Please run ./scripts/build.sh first."
    exit 1 # Critical: cannot run tests
fi
log_success "✅ HenSurf binary found at '$HENSURF_BINARY_PATH'"

# Create temporary test directory
TEST_DIR="/tmp/hensurf-test-$(date +%s)"
mkdir -p "$TEST_DIR"
log_info "📁 Created test directory: $TEST_DIR"

# Common HenSurf arguments
HENSURF_ARGS_COMMON=(
    "--user-data-dir=\"$TEST_DIR/profile\"" # Use a common profile for most tests, or unique ones if needed
    "--no-first-run"
    "--disable-background-timer-updates"
    "--disable-backgrounding-occluded-windows"
    "--disable-renderer-backgrounding"
    "--headless"
    "--dump-dom"
)

# Test 1: Basic startup
# Command needs to be a single string for eval in run_test
startup_cmd="timeout 10s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=1000 \"data:text/html,<html><body><h1>HenSurf Startup Test</h1></body></html>\" > \"$TEST_DIR/startup_test.html\" 2>&1"
startup_condition="grep -q 'HenSurf Startup Test' \"$TEST_DIR/startup_test.html\""
run_test "Basic startup test" "$startup_cmd" "$TEST_DIR/startup_test.html" "$startup_condition"


# Test 2: Check default search engine
search_cmd="timeout 6s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=2000 \"chrome://settings/search\" > \"$TEST_DIR/search_test.html\" 2>&1"
search_condition="grep -q -i 'duckduckgo\\|duck' \"$TEST_DIR/search_test.html\""
# This test is more of a check; if it fails, it's a warning rather than a hard failure for script exit.
# The run_test function will increment FAIL_COUNT, which will be reflected in the final summary.
run_test "Default search engine" "$search_cmd" "$TEST_DIR/search_test.html" "$search_condition"


# Test 3: Check for Google services (should be absent)
settings_cmd="timeout 6s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --enable-logging --log-level=0 --virtual-time-budget=2000 \"chrome://settings/\" > \"$TEST_DIR/settings_test.html\" 2>&1"
# Success if Google-related terms are NOT found
settings_condition="! grep -q -i 'google account\\|sync.*google\\|sign.*in.*google' \"$TEST_DIR/settings_test.html\""
run_test "Google services removal" "$settings_cmd" "$TEST_DIR/settings_test.html" "$settings_condition"


# Test 4: Privacy settings
privacy_cmd="timeout 6s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=2000 \"chrome://settings/privacy\" > \"$TEST_DIR/privacy_test.html\" 2>&1"
privacy_condition="[ -s \"$TEST_DIR/privacy_test.html\" ]" # Check if file is not empty
run_test "Privacy settings accessibility" "$privacy_cmd" "$TEST_DIR/privacy_test.html" "$privacy_condition"


# Test 5: Extension support
extensions_cmd="timeout 6s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=2000 \"chrome://extensions/\" > \"$TEST_DIR/extensions_test.html\" 2>&1"
extensions_condition="[ -s \"$TEST_DIR/extensions_test.html\" ]" # Check if file is not empty
run_test "Extensions page accessibility" "$extensions_cmd" "$TEST_DIR/extensions_test.html" "$extensions_condition"


# Test 6: Version information
# This test doesn't use run_test as it's not a dump-dom style test
TEST_COUNT=$((TEST_COUNT + 1))
log_info "🚀 Test $TEST_COUNT: Version information..."
VERSION_OUTPUT=$("$HENSURF_BINARY_PATH" --version 2>&1 || echo "Version check failed")
log_info "   Version: $VERSION_OUTPUT"
if echo "$VERSION_OUTPUT" | grep -q -i "hensurf\\|chromium"; then
    log_success "   ✅ Version information available"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log_error "   ❌ Version information test inconclusive or failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi


# Test 7: Network connectivity test
network_cmd="timeout 8s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=5000 \"https://duckduckgo.com\" > \"$TEST_DIR/network_test.html\" 2>&1"
network_condition="grep -q -i 'duckduckgo\\|search' \"$TEST_DIR/network_test.html\""
run_test "Network connectivity (duckduckgo.com)" "$network_cmd" "$TEST_DIR/network_test.html" "$network_condition"


# Test 8: Default homepage test (should be about:blank)
# Using a unique user data dir for this test to simulate first launch for homepage
homepage_args_specific=(
    "--user-data-dir=\"$TEST_DIR/homepage-profile\""
    "--no-first-run"
    "--headless"
    "--dump-dom"
    "--virtual-time-budget=500"
)
homepage_cmd="\"$HENSURF_BINARY_PATH\" ${homepage_args_specific[*]} > \"$TEST_DIR/homepage_test.html\" 2>&1"
# about:blank is very minimal, often just <html><head></head><body></body></html> or empty body
homepage_condition="grep -q -E '<body(\\s[^>]*)?>\\s*</body>' \"$TEST_DIR/homepage_test.html\" || ( [ \"\$(wc -c <\\\"$TEST_DIR/homepage_test.html\\\")\" -lt 300 ] && grep -q '<head></head>' \"$TEST_DIR/homepage_test.html\" )"
run_test "Default homepage (about:blank)" "$homepage_cmd" "$TEST_DIR/homepage_test.html" "$homepage_condition"


# Test 9: Performance test (simple startup time)
# This test also doesn't use run_test as it's measuring time.
TEST_COUNT=$((TEST_COUNT + 1))
log_info "🚀 Test $TEST_COUNT: Performance test (simple startup time)..."
START_TIME_PERF=$(date +%s%N)
# Use HENSURF_ARGS_COMMON but with a specific user-data-dir for this perf test if needed, or reuse common.
perf_user_data_dir="$TEST_DIR/perf-profile"
mkdir -p "$perf_user_data_dir"
perf_args=(
    "--user-data-dir=\"$perf_user_data_dir\""
    "--no-first-run"
    "--headless"
    "--dump-dom" # Still useful to ensure it does something
    "--virtual-time-budget=1000"
)
eval "\"$HENSURF_BINARY_PATH\" ${perf_args[*]} \"data:text/html,<html><body>Performance Test</body></html>\" > /dev/null 2>&1"
perf_exit_code=$?
END_TIME_PERF=$(date +%s%N)
DURATION=$(( (END_TIME_PERF - START_TIME_PERF) / 1000000 ))

if [ $perf_exit_code -eq 0 ]; then
    log_success "   ✅ Performance test completed in ${DURATION}ms."
    PASS_COUNT=$((PASS_COUNT + 1))
else
    log_error "   ❌ Performance test process failed with code $perf_exit_code."
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# --- New Test Cases ---

# Test 10: Bookmarks Page
bookmarks_url="chrome://bookmarks/"
bookmarks_file="$TEST_DIR/bookmarks_page.html"
bookmarks_cmd="timeout 6s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=2000 \"$bookmarks_url\" > \"$bookmarks_file\" 2>&1"
bookmarks_condition="[ -s \"$bookmarks_file\" ] && grep -q -i 'Bookmarks\\|Organize' \"$bookmarks_file\""
run_test "Bookmarks Page ($bookmarks_url)" "$bookmarks_cmd" "$bookmarks_file" "$bookmarks_condition"

# Test 11: History Page
# First, visit a page to create some history
history_prereq_url="data:text/html,VisitedPageForHistory"
history_prereq_file="$TEST_DIR/history_prereq.html"
history_prereq_cmd="timeout 6s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=1000 \"$history_prereq_url\" > \"$history_prereq_file\" 2>&1"
eval "$history_prereq_cmd" # Just run it, success checked by history page load

history_url="chrome://history/"
history_file="$TEST_DIR/history_page.html"
history_cmd="timeout 6s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=2000 \"$history_url\" > \"$history_file\" 2>&1"
history_condition="[ -s \"$history_file\" ] && grep -q -i 'History\\|Clear browsing data' \"$history_file\""
run_test "History Page ($history_url)" "$history_cmd" "$history_file" "$history_condition"

# Test 12: Downloads Page
downloads_url="chrome://downloads/"
downloads_file="$TEST_DIR/downloads_page.html"
downloads_cmd="timeout 6s \"$HENSURF_BINARY_PATH\" ${HENSURF_ARGS_COMMON[*]} --virtual-time-budget=2000 \"$downloads_url\" > \"$downloads_file\" 2>&1"
downloads_condition="[ -s \"$downloads_file\" ] && grep -q -i 'Downloads\\|No downloads' \"$downloads_file\""
run_test "Downloads Page ($downloads_url)" "$downloads_cmd" "$downloads_file" "$downloads_condition"


# Cleanup
log_info "🧹 Cleaning up test directory: $TEST_DIR"
rm -rf "$TEST_DIR"
log_success "✅ Test directory cleaned up."

log_info ""
log_info "--- Test Summary ---"
log_info "Total tests run: $TEST_COUNT"
log_success "Tests PASSED: $PASS_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    log_error "Tests FAILED: $FAIL_COUNT"
else
    log_success "Tests FAILED: 0"
fi
log_info "--------------------"
log_info ""


if [ "$FAIL_COUNT" -gt 0 ]; then
    log_error "❌ Some tests failed. HenSurf Browser may not be fully functional."
    exit 1
else
    log_success "🎉 All HenSurf tests passed successfully!"
    log_info "🚀 HenSurf is ready to use!"
    log_info "To run HenSurf (from project root):"
    # Determine if it's a macOS .app bundle
    HENSURF_APP_PATH_GUESS_1="$PROJECT_ROOT/$HENSURF_BINARY_PATH.app" # if HENSURF_BINARY_PATH was just 'chrome'
    HENSURF_APP_PATH_GUESS_2=$(dirname "$HENSURF_BINARY_PATH")/HenSurf.app # if HENSURF_BINARY_PATH was full path to executable inside .app

    if [ -d "$HENSURF_APP_PATH_GUESS_2" ]; then
        log_info "   open $HENSURF_APP_PATH_GUESS_2"
    elif [ -d "$HENSURF_APP_PATH_GUESS_1" ] && [[ "$HENSURF_BINARY_PATH" != *.app* ]]; then # Avoid double .app
        log_info "   open $HENSURF_APP_PATH_GUESS_1"
    else
        log_info "   ./$HENSURF_BINARY_PATH"
    fi
    log_info "For more testing options:"
    log_info "   ./$HENSURF_BINARY_PATH --help"
    exit 0
fi
# No changes needed below this line for this specific diff block
# The rest of the script is refactored to use run_test or has been updated.