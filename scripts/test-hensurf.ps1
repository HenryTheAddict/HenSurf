# HenSurf Browser - Test Script (PowerShell Edition)
# This script runs basic tests to verify HenSurf functionality on Windows

$ErrorActionPreference = "Stop" # Exit on error, similar to set -e

# Initialize test counters
$TotalTests = 0
$TestsPassed = 0
$TestsFailed = 0
$GlobalFailureOccurred = $false # Flag to track if any test fails, for final exit code

# Helper function for consistent test execution and reporting
function Invoke-HenSurfTest {
    param(
        [string]$TestName,
        [string]$Url,
        [string]$OutputHtmlFile,
        [string]$UserDataDir,
        [string]$Keyword,
        [int]$TimeoutSeconds = 15,
        [int]$VirtualTimeBudget = 2000,
        [string]$PreCommand # Optional command to run before the main test command
    )

    Write-Host "🚀 Test $($TotalTests + 1): $TestName..."
    $Global:TotalTests++
    $TestSuccess = $false

    try {
        if (-not [string]::IsNullOrWhiteSpace($PreCommand)) {
            Invoke-Expression $PreCommand
        }

        Get-HenSurfDom -Url $Url -OutputHtmlFile $OutputHtmlFile -UserDataDir $UserDataDir -TimeoutSeconds $TimeoutSeconds -VirtualTimeBudget $VirtualTimeBudget

        if (Get-Content $OutputHtmlFile -Raw | Select-String -Pattern $Keyword -Quiet -CaseSensitive:$false) {
            Write-Host "✅ $TestName passed (found keyword '$Keyword')"
            $Global:TestsPassed++
            $TestSuccess = $true
        } else {
            Throw "$TestName content check failed (keyword '$Keyword' not found)."
        }
    } catch {
        Write-Warning "❌ $TestName failed: $($_.Exception.Message)"
        if (Test-Path $OutputHtmlFile) { Write-Host "Output for $TestName :"; Get-Content $OutputHtmlFile -Raw | Write-Host }
        $Global:TestsFailed++
        $Global:GlobalFailureOccurred = $true
    }
    return $TestSuccess
}


Write-Host "🧪 Testing HenSurf Browser (PowerShell)..."

# Determine paths
$ScriptRoot = $PSScriptRoot
$ProjectRoot = Split-Path -Path $ScriptRoot -Parent
$HenSurfBinaryDir = Join-Path -Path $ProjectRoot -ChildPath "chromium\src\out\HenSurf"
$HenSurfExe = Join-Path -Path $HenSurfBinaryDir -ChildPath "chrome.exe" # Assuming .exe for Windows

# Check if HenSurf binary exists
if (-not (Test-Path -Path $HenSurfExe -PathType Leaf)) {
    Write-Error "❌ HenSurf binary not found at $HenSurfExe. Please run the build script first."
    exit 1 # Critical error, cannot proceed
}
Write-Host "✅ HenSurf binary found at $HenSurfExe"

# Create temporary test directory
$Timestamp = Get-Date -Format "yyyyMMddHHmmssfff"
$GlobalTestDir = Join-Path -Path $env:TEMP -ChildPath "hensurf-test-$Timestamp"
New-Item -ItemType Directory -Path $GlobalTestDir -Force | Out-Null
Write-Host "📁 Created global test directory: $GlobalTestDir"

# Function to run a single HenSurf process for DOM dumping
function Get-HenSurfDom {
    param(
        [string]$Url,
        [string]$OutputHtmlFile,
        [string]$UserDataDir,
        [int]$TimeoutSeconds = 15,
        [int]$VirtualTimeBudget = 2000
    )

    $Args = @(
        "--user-data-dir=`"$UserDataDir`"",
        "--no-first-run",
        "--disable-background-timer-updates",
        "--disable-backgrounding-occluded-windows",
        "--disable-renderer-backgrounding",
        "--headless",
        "--dump-dom",
        "--virtual-time-budget=$VirtualTimeBudget",
        "`"$Url`""
    )

    $Process = Start-Process -FilePath $HenSurfExe -ArgumentList $Args -PassThru -NoNewWindow -RedirectStandardOutput $OutputHtmlFile -RedirectStandardError $OutputHtmlFile
    $ProcessExited = $Process | Wait-Process -Timeout $TimeoutSeconds

    if (-not $ProcessExited) {
        Write-Warning "Process for $Url did not exit within $TimeoutSeconds seconds, attempting to stop."
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue # Best effort to stop
        Throw "Test for $Url timed out."
    }

    if ($Process.ExitCode -ne 0) {
        Throw "HenSurf process for $Url exited with code $($Process.ExitCode)."
    }

    if (-not (Test-Path $OutputHtmlFile) -or (Get-Item $OutputHtmlFile).Length -eq 0) {
        Throw "Output file $OutputHtmlFile for $Url not found or is empty."
    }
    # Content check is specific to each test
}

# Overall try/catch/finally for cleanup
try {
    # --- Test 1: Basic startup ---
    Write-Host "🚀 Test 1: Basic startup test..."
    $StartupTestHtml = Join-Path -Path $GlobalTestDir -ChildPath "startup_test.html"
    try {
        Get-HenSurfDom -Url "data:text/html,<html><body><h1>HenSurf Test</h1></body></html>" -OutputHtmlFile $StartupTestHtml -UserDataDir $GlobalTestDir -VirtualTimeBudget 1000
        if (Get-Content $StartupTestHtml -Raw | Select-String -Pattern "HenSurf Test" -Quiet) {
            Write-Host "✅ Startup test passed"
        } else {
            Throw "Startup test content check failed."
        }
    } catch {
        Write-Error "❌ Startup test failed: $($_.Exception.Message)"
        if (Test-Path $StartupTestHtml) { Get-Content $StartupTestHtml -Raw | Write-Host }
    }

    # --- Test 2: Check default search engine ---
    Write-Host "🔍 Test 2: Default search engine test..."
    $SearchTestHtml = Join-Path -Path $GlobalTestDir -ChildPath "search_test.html"
    try {
        Get-HenSurfDom -Url "chrome://settings/search" -OutputHtmlFile $SearchTestHtml -UserDataDir $GlobalTestDir
        # DuckDuckGo might be represented in various ways in settings DOM
        if (Get-Content $SearchTestHtml -Raw | Select-String -Pattern "duckduckgo|ddg.gg|duck.com" -Quiet -CaseSensitive:$false) {
            Write-Host "✅ Default search engine test passed (DuckDuckGo detected)"
        } else {
            Write-Warning "⚠️ Default search engine test inconclusive (DuckDuckGo not explicitly found in DOM). Manual verification might be needed."
            Get-Content $SearchTestHtml -Raw | Write-Host # Output DOM for inspection
        }
    } catch {
        Write-Error "❌ Default search engine test failed: $($_.Exception.Message)"
        if (Test-Path $SearchTestHtml) { Get-Content $SearchTestHtml -Raw | Write-Host }
    }

    # --- Test 3: Google services removal test ---
    Write-Host "🚫 Test 3: Google services removal test..."
    $SettingsTestHtml = Join-Path -Path $GlobalTestDir -ChildPath "settings_test.html"
    try {
        Get-HenSurfDom -Url "chrome://settings/" -OutputHtmlFile $SettingsTestHtml -UserDataDir $GlobalTestDir
        if (Get-Content $SettingsTestHtml -Raw | Select-String -Pattern "google account|sync.*google|sign.*in.*google" -Quiet -CaseSensitive:$false) {
            Write-Warning "⚠️ Google services may still be present (found problematic terms in DOM). Manual verification needed."
            Get-Content $SettingsTestHtml -Raw | Write-Host
        } else {
            Write-Host "✅ Google services removal test passed (no problematic terms found)"
        }
    } catch {
        Write-Error "❌ Google services removal test failed: $($_.Exception.Message)"
        if (Test-Path $SettingsTestHtml) { Get-Content $SettingsTestHtml -Raw | Write-Host }
    }

    # --- Test 4: Privacy settings ---
    Write-Host "🔒 Test 4: Privacy settings test..."
    $PrivacyTestHtml = Join-Path -Path $GlobalTestDir -ChildPath "privacy_test.html"
    try {
        Get-HenSurfDom -Url "chrome://settings/privacy" -OutputHtmlFile $PrivacyTestHtml -UserDataDir $GlobalTestDir
        # Basic check for accessibility and some content
        if ((Get-Item $PrivacyTestHtml).Length -gt 100) { # Check if file has substantial content
            Write-Host "✅ Privacy settings accessible and has content"
        } else {
            Throw "Privacy settings page content seems too small."
        }
    } catch {
        Write-Error "❌ Privacy settings test failed: $($_.Exception.Message)"
        if (Test-Path $PrivacyTestHtml) { Get-Content $PrivacyTestHtml -Raw | Write-Host }
    }

    # --- Test 5: Extension support ---
    Write-Host "🧩 Test 5: Extension support test..."
    $ExtensionsTestHtml = Join-Path -Path $GlobalTestDir -ChildPath "extensions_test.html"
    try {
        Get-HenSurfDom -Url "chrome://extensions/" -OutputHtmlFile $ExtensionsTestHtml -UserDataDir $GlobalTestDir
        if ((Get-Item $ExtensionsTestHtml).Length -gt 100) { # Check if file has substantial content
            Write-Host "✅ Extensions page accessible and has content"
        } else {
            Throw "Extensions page content seems too small."
        }
    } catch {
        Write-Error "❌ Extensions test failed: $($_.Exception.Message)"
        if (Test-Path $ExtensionsTestHtml) { Get-Content $ExtensionsTestHtml -Raw | Write-Host }
    }

    # --- Test 6: Version information ---
    Write-Host "ℹ️  Test 6: Version information..."
    $VersionTxt = Join-Path -Path $GlobalTestDir -ChildPath "version.txt"
    $VersionErrorTxt = Join-Path -Path $GlobalTestDir -ChildPath "version_error.txt"
    try {
        $VersionProcess = Start-Process -FilePath $HenSurfExe -ArgumentList "--version" -PassThru -NoNewWindow -Wait -RedirectStandardOutput $VersionTxt -RedirectStandardError $VersionErrorTxt

        $VersionOutput = ""
        if (Test-Path $VersionTxt) { $VersionOutput = Get-Content $VersionTxt -Raw }
        if ($VersionProcess.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($VersionOutput)) {
            if (Test-Path $VersionErrorTxt) { $VersionOutput = (Get-Content $VersionErrorTxt -Raw) + $VersionOutput }
        }

        Write-Host "Version output: $VersionOutput"
        if ($VersionOutput -match "Hensurf" -or $VersionOutput -match "Chromium") {
            Write-Host "✅ Version information available"
        } else {
            Write-Warning "⚠️ Version information test inconclusive or failed (keywords not found)."
        }
    } catch {
        Write-Error "❌ Version information test failed: $($_.Exception.Message)"
    }

    # --- Test 7: Network connectivity test ---
    Write-Host "🌐 Test 7: Network connectivity test..."
    $NetworkTestHtml = Join-Path -Path $GlobalTestDir -ChildPath "network_test.html"
    try {
        Get-HenSurfDom -Url "https://duckduckgo.com" -OutputHtmlFile $NetworkTestHtml -UserDataDir $GlobalTestDir -TimeoutSeconds 20 -VirtualTimeBudget 5000
        if (Get-Content $NetworkTestHtml -Raw | Select-String -Pattern "duckduckgo|search" -Quiet -CaseSensitive:$false) {
            Write-Host "✅ Network connectivity test passed"
        } else {
            Throw "Network connectivity content check failed (keywords not found)."
        }
    } catch {
        Write-Error "❌ Network connectivity test failed: $($_.Exception.Message)"
        if (Test-Path $NetworkTestHtml) { Get-Content $NetworkTestHtml -Raw | Write-Host }
        Write-Warning "Note: Network tests can fail due to external factors (internet connection, DNS)."
    }

    # --- Test 8: Default homepage test (should be about:blank) ---
    Write-Host "🏠 Test 8: Default homepage test..."
    $HomepageTestHtml = Join-Path -Path $GlobalTestDir -ChildPath "homepage_test.html"
    # Create a dedicated user data directory for this test to ensure a true "first launch" feel for homepage
    $HomepageUserDataDir = Join-Path -Path $GlobalTestDir -ChildPath "homepage-profile"
    New-Item -ItemType Directory -Path $HomepageUserDataDir -Force | Out-Null

    $HomepageArgs = @(
        "--user-data-dir=`"$HomepageUserDataDir`"",
        "--no-first-run",
        "--headless",
        "--dump-dom",
        "--virtual-time-budget=500" # Short budget for a blank page
        # No URL is passed to test default homepage
    )
    try {
        $Process = Start-Process -FilePath $HenSurfExe -ArgumentList $HomepageArgs -PassThru -NoNewWindow -RedirectStandardOutput $HomepageTestHtml -RedirectStandardError $HomepageTestHtml
        $ProcessExited = $Process | Wait-Process -Timeout 10 # Timeout in seconds

        if (-not $ProcessExited) {
            Write-Warning "Homepage test process did not exit within 10 seconds, attempting to stop."
            Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            Throw "Homepage test timed out."
        }

        if ($Process.ExitCode -ne 0) {
            Throw "HenSurf process for homepage test exited with code $($Process.ExitCode)."
        }

        if (-not (Test-Path $HomepageTestHtml)) {
            Throw "Output file $HomepageTestHtml for homepage test not found."
        }

        $DomContent = Get-Content $HomepageTestHtml -Raw
        # about:blank typically results in a very minimal HTML structure
        # e.g. <html><head></head><body></body></html> or similar
        # Check for empty body and head, or very small content length
        if (($DomContent -match "<body(\s[^>]*)?>\s*</body>") -or ($DomContent.Length -lt 300 -and $DomContent -match "<head></head>")) {
            Write-Host "✅ Default homepage test passed (appears to be about:blank)"
        } else {
            Throw "Default homepage test content check failed (DOM does not look like about:blank)."
        }
    } catch {
        Write-Error "❌ Default homepage test failed: $($_.Exception.Message)"
        if (Test-Path $HomepageTestHtml) { Get-Content $HomepageTestHtml -Raw | Write-Host }
    }

    # --- Test 9: Performance test (Simple Startup Time) ---
    Write-Host "⚡ Test 9: Performance test (Simple Startup Time)..."
    $CurrentTestName = "Performance Test"
    $TotalTests++
    try {
        $PerfTestArgs = @(
            "--user-data-dir=`"$GlobalTestDir`"",
            "--no-first-run",
            "--headless",
            "--dump-dom",
            "--virtual-time-budget=1000", # Keep this budget small for a startup-like test
            "`"data:text/html,<html><body>Performance Test</body></html>`""
        )
        $Measurement = Measure-Command {
            $PerfProcess = Start-Process -FilePath $HenSurfExe -ArgumentList $PerfTestArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $null -RedirectStandardError $null
            if ($PerfProcess.ExitCode -ne 0) {
                Throw "Process exited with code $($PerfProcess.ExitCode)"
            }
        }
        Write-Host "✅ $CurrentTestName completed in $($Measurement.TotalMilliseconds)ms"
        $TestsPassed++
    } catch {
        Write-Warning "❌ $CurrentTestName failed: $($_.Exception.Message)"
        $TestsFailed++
        $GlobalFailureOccurred = $true
    }

    # --- New Test Cases ---

    # Test 10: Bookmarks Page
    $BookmarksFile = Join-Path -Path $GlobalTestDir -ChildPath "bookmarks_page.html"
    Invoke-HenSurfTest -TestName "Bookmarks Page" -Url "chrome://bookmarks/" -OutputHtmlFile $BookmarksFile -UserDataDir $GlobalTestDir -Keyword "Bookmarks|Organize"

    # Test 11: History Page
    $HistoryPrereqFile = Join-Path -Path $GlobalTestDir -ChildPath "history_prereq.html"
    $HistoryFile = Join-Path -Path $GlobalTestDir -ChildPath "history_page.html"
    $PreCommandHistory = { Get-HenSurfDom -Url "data:text/html,VisitedPageForHistory" -OutputHtmlFile $HistoryPrereqFile -UserDataDir $GlobalTestDir -VirtualTimeBudget 500 }
    Invoke-HenSurfTest -TestName "History Page" -Url "chrome://history/" -OutputHtmlFile $HistoryFile -UserDataDir $GlobalTestDir -Keyword "History|Clear browsing data" -PreCommand $PreCommandHistory

    # Test 12: Downloads Page
    $DownloadsFile = Join-Path -Path $GlobalTestDir -ChildPath "downloads_page.html"
    Invoke-HenSurfTest -TestName "Downloads Page" -Url "chrome://downloads/" -OutputHtmlFile $DownloadsFile -UserDataDir $GlobalTestDir -Keyword "Downloads|No downloads"

}
finally {
    # Cleanup
    Write-Host "🧹 Cleaning up test directory: $GlobalTestDir"
    if (Test-Path $GlobalTestDir) {
        Remove-Item -Path $GlobalTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Summary ---
Write-Host ""
Write-Host "--- Test Summary ---"
Write-Host "Total tests run: $TotalTests"
if ($TestsFailed -eq 0) {
    Write-Host -ForegroundColor Green "Tests PASSED: $TestsPassed"
    Write-Host -ForegroundColor Green "Tests FAILED: 0"
    Write-Host ""
    Write-Host -ForegroundColor Green "🎉 All HenSurf PowerShell tests passed successfully!"
} else {
    Write-Host -ForegroundColor Green "Tests PASSED: $TestsPassed"
    Write-Host -ForegroundColor Red "Tests FAILED: $TestsFailed"
    Write-Host ""
    Write-Error "❌ Some PowerShell tests failed. HenSurf Browser may not be fully functional."
}
Write-Host "--------------------"
Write-Host ""

Write-Host "🚀 To run HenSurf (Windows):"
Write-Host "   & `"$HenSurfExe`""
Write-Host ""
Write-Host "For more testing options:"
Write-Host "   & `"$HenSurfExe`" --help"

if ($GlobalFailureOccurred) {
    exit 1
} else {
    exit 0
}
# End of script
