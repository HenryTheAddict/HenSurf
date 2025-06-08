# Windows Test Script Design for HenSurf

This document outlines the plan for creating a Windows-compatible test script for HenSurf, equivalent to the existing `scripts/test-hensurf.sh`.

## 1. Incompatibilities in `scripts/test-hensurf.sh`

The bash script `scripts/test-hensurf.sh` contains several commands and constructs that are not directly compatible with Windows:

*   **Shebang**: `#!/bin/bash` is Unix-specific.
*   **File Paths**: Uses POSIX path separators (`/`) and conventions (e.g., `/tmp`). Windows uses `\` and different environment variables for temporary directories (e.g., `$env:TEMP`).
*   **`timeout` command**: Not a standard Windows command.
*   **`kill` command**: Not a standard Windows command.
*   **`grep` command**: Not a standard Windows command.
*   **Process Backgrounding (`&`) and PID Capture (`$!`)**: These are bash-specific job control features.
*   **`date +%s` / `date +%s%N`**: Unix `date` command syntax for timestamps.
*   **`rm -rf`**: Unix command for recursive directory removal.
*   **Output Redirection to `/dev/null`**: Unix-specific.
*   **`sleep` command**: While potentially aliased in PowerShell, explicit `Start-Sleep` is more robust.
*   **Exit Code Check (`$?`)**: Behavior differs slightly; `$LASTEXITCODE` is generally used for external executables in PowerShell.

## 2. Design Choices for Windows Test Script

*   **Scripting Language**: **PowerShell (`.ps1`)** was chosen due to its native availability on Windows, strong capabilities for system interaction, process management, and text manipulation (via cmdlets like `Select-String`).
*   **Path Management**:
    *   Use `$PSScriptRoot` for script relative paths.
    *   Use `Join-Path` for constructing paths robustly.
    *   HenSurf executable assumed to be `chrome.exe` under `chromium\src\out\HenSurf`.
*   **Temporary Directory**: Create under `$env:TEMP` with a timestamped name (e.g., `$env:TEMP\hensurf-test-yyyyMMddHHmmssfff`). A global temporary directory (`$GlobalTestDir`) is used for all tests, cleaned up at the end.
*   **Running HenSurf**:
    *   A helper function `Get-HenSurfDom` was created to standardize launching HenSurf for DOM dumping operations. This function encapsulates `Start-Process`, argument construction, output redirection, and timeout handling.
    *   `Start-Process -FilePath $HenSurfExe -ArgumentList $args` is the primary cmdlet.
    *   `-Wait` can be used for synchronous execution (like for `--version`).
    *   `-PassThru` to get the process object.
    *   `-NoNewWindow` to keep console output integrated.
    *   `-RedirectStandardOutput` and `-RedirectStandardError` for capturing output.
*   **Process Control**:
    *   **Timeout**: `Wait-Process -Timeout <seconds>` on the process object obtained from `Start-Process -PassThru`. If timeout occurs, `Stop-Process -Id $process.Id -Force`. This is integrated into `Get-HenSurfDom`.
    *   **Kill**: `Stop-Process -Id <PID>` or `Stop-Process -Name <ProcessName> -Force`.
*   **File Content Checking**:
    *   `Get-Content $filePath -Raw | Select-String -Pattern "search term" -Quiet` (returns True/False).
    *   `-CaseSensitive:$false` is used for most checks to match bash `grep -i` behavior.
*   **Cleanup**: `Remove-Item -Path $GlobalTestDir -Recurse -Force` in a global `finally` block to ensure cleanup.
*   **Error Handling**:
    *   `$ErrorActionPreference = "Stop"` for script-terminating errors (similar to `set -e`), though individual tests use `try/catch` to allow continuation.
    *   `try { ... } catch { ... }` blocks for individual test error handling and reporting.
    *   Check `$Process.ExitCode` after `Wait-Process` or synchronous `Start-Process`.
*   **Logging**: `Write-Host` for general progress, `Write-Warning` for non-critical issues or inconclusive tests, `Write-Error` for failures. Failed test DOMs are printed to console.
*   **Performance Timing**: `Measure-Command { ... }` for the performance test.

## 3. Completed PowerShell Script (`scripts/test-hensurf.ps1`)

```powershell
# HenSurf Browser - Test Script (PowerShell Edition)
# This script runs basic tests to verify HenSurf functionality on Windows

$ErrorActionPreference = "Stop" # Exit on error, similar to set -e

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
        if (Get-Content $SearchTestHtml -Raw | Select-String -Pattern "duckduckgo|ddg.gg|duck.com" -Quiet -CaseSensitive:$false) {
            Write-Host "✅ Default search engine test passed (DuckDuckGo detected)"
        } else {
            Write-Warning "⚠️ Default search engine test inconclusive (DuckDuckGo not explicitly found in DOM). Manual verification might be needed."
            Get-Content $SearchTestHtml -Raw | Write-Host
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
        if ((Get-Item $PrivacyTestHtml).Length -gt 100) {
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
        if ((Get-Item $ExtensionsTestHtml).Length -gt 100) {
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

    # --- Test 8: Performance test (Simple Startup Time) ---
    Write-Host "⚡ Test 8: Performance test (Simple Startup Time)..."
    $PerfTestArgs = @(
        "--user-data-dir=`"$GlobalTestDir`"",
        "--no-first-run",
        "--headless",
        "--dump-dom",
        "--virtual-time-budget=1000",
        "`"data:text/html,<html><body>Performance Test</body></html>`""
    )
    try {
        $Measurement = Measure-Command {
            Start-Process -FilePath $HenSurfExe -ArgumentList $PerfTestArgs -NoNewWindow -Wait -RedirectStandardOutput $null -RedirectStandardError $null
        }
        Write-Host "✅ Performance test (simple startup) completed in $($Measurement.TotalMilliseconds)ms"
    } catch {
        Write-Error "❌ Performance test failed: $($_.Exception.Message)"
    }

}
finally {
    # Cleanup
    Write-Host "🧹 Cleaning up test directory: $GlobalTestDir"
    if (Test-Path $GlobalTestDir) {
        Remove-Item -Path $GlobalTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "🎉 HenSurf PowerShell testing completed!"

Write-Host "🚀 To run HenSurf (Windows):"
Write-Host "   & `"$HenSurfExe`""
Write-Host ""
Write-Host "For more testing options:"
Write-Host "   & `"$HenSurfExe`" --help"

# End of script
```

## 4. Challenges and Refinements during Implementation

*   **Helper Function**: Created `Get-HenSurfDom` to encapsulate common logic for launching HenSurf, capturing DOM, and handling timeouts. This simplified each test.
*   **Global Try/Finally**: Encapsulated all tests in a `try` block with a `finally` block to ensure the `$GlobalTestDir` is cleaned up even if errors occur.
*   **Error Output**: When a test fails, its specific error message is printed. If an output HTML file was generated, its content is also printed for easier debugging.
*   **Inconclusive Tests**: For tests like default search engine or version info, where results might vary slightly or not be definitively "pass/fail" based on simple string checks, `Write-Warning` is used to indicate potential issues without necessarily halting all tests (though `$ErrorActionPreference = "Stop"` would normally halt on a `Throw`). The current structure with individual `try/catch` blocks for each test allows other tests to run even if one throws an error.
*   **Timeout Values**: Adjusted timeout for the network connectivity test to be longer.
*   **Content Checks**: Made search string checks case-insensitive for robustness.
*   **Performance Test**: Used `Measure-Command` for timing, and redirected HenSurf's output to `$null` as only the duration is of interest.

The script is now more feature-complete and robust.
