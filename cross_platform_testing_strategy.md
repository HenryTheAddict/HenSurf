# Cross-Platform Testing Strategy for HenSurf

This document outlines identified gaps in current testing, brainstorms test ideas for these gaps, and proposes a design for a cross-platform test runner.

## 1. Identified Test Gaps (from `config/features.json` vs. `test-hensurf.sh`)

**Key Gaps:**

*   **Safe Browsing (`replaced_with_local`)**: Current tests don't verify if Safe Browsing is local or makes Google API calls.
*   **Telemetry/Analytics Removal**: No tests actively check for outgoing pings to known telemetry/analytics endpoints.
*   **Crash Reporting (`made_optional`)**: Default state and toggle mechanism untested.
*   **Third-Party Cookie Blocking**: Not explicitly tested.
*   **Cross-Site Tracking Prevention**: Broad claim, needs specific test cases.
*   **Fingerprinting Protection**: Specific API checks are missing.
*   **DNS-over-HTTPS (DoH)**: Not tested.
*   **Referrer Policy (`strict`)**: Not tested.
*   **HTTPS-Only Mode (`available`)**: Not tested.
*   **HSTS Enforcement**: Not tested (may be covered by some Chromium `browser_tests`).
*   **Site Isolation / Process Sandboxing**: Assumed Chromium defaults, but "enhanced" sandboxing is untested.
*   **Default Homepage (`about:blank`)**: **Addressed in Subtask 7 by adding Test 8 to `test-hensurf.sh` and `test-hensurf.ps1`.**
*   **New Tab Page (`minimal`)**: Not tested.
*   **Cookie Policy (`session_only`)**: Not tested.

## 2. Test Ideas for Gaps
_(Test ideas remain largely the same as previous version, with "Default Homepage" now marked as addressed)._
... (sections a-l from previous version of this file) ...

## 3. Cross-Platform Test Runner Implementation (`scripts/run_all_tests.py`)

The following Python script has been implemented:
```python
# scripts/run_all_tests.py
import os
import platform
import subprocess
import argparse
import sys

# Paths (assuming script is in /app/scripts/)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, '..'))
HENSURF_SRC_DIR = os.path.join(PROJECT_ROOT, 'chromium', 'src')
HENSURF_OUT_DIR_DEFAULT = os.path.join(HENSURF_SRC_DIR, 'out', 'HenSurf')
MOCK_TOOLS_DIR = os.path.join(PROJECT_ROOT, 'tmp_mocks')
DEPOT_TOOLS_MOCK_DIR = os.path.join(PROJECT_ROOT, 'depot_tools_mock')

def get_env_with_mock_tools():
    env = os.environ.copy()
    env['PATH'] = MOCK_TOOLS_DIR + os.pathsep + DEPOT_TOOLS_MOCK_DIR + os.pathsep + env.get('PATH', '')
    return env

def run_command(cmd_list, working_dir=None, timeout_seconds=300, env=None, check_exit_code=True):
    print(f"Executing: {' '.join(cmd_list)} in {working_dir or os.getcwd()}")
    try:
        process_env = env if env else os.environ.copy()
        process = subprocess.run(cmd_list, cwd=working_dir, capture_output=True, text=True,
                                 timeout=timeout_seconds, env=process_env, check=False)

        stdout_lines = process.stdout.splitlines()
        stderr_lines = process.stderr.splitlines()

        print("STDOUT:")
        for line in stdout_lines: print(line)
        if stderr_lines:
            print("STDERR:")
            for line in stderr_lines: print(line)

        if check_exit_code:
            if process.returncode == 0:
                print("Command SUCCEEDED.")
                return True
            else:
                print(f"Command FAILED with exit code {process.returncode}.")
                return False
        print(f"Command finished with exit code {process.returncode} (not checked for success).")
        return True
    except subprocess.TimeoutExpired:
        print(f"Command timed out after {timeout_seconds} seconds."); return False
    except Exception as e:
        print(f"Error running command: {e}"); return False

def main():
    parser = argparse.ArgumentParser(description="HenSurf Cross-Platform Test Runner")
    parser.add_argument('--platform', default=platform.system().lower(), choices=['linux', 'windows', 'darwin'], help="OS platform")
    parser.add_argument('--output-dir', default=HENSURF_OUT_DIR_DEFAULT, help="Chromium output directory")
    parser.add_argument('--skip-custom-scripts', action='store_true', help="Skip test-hensurf.sh/ps1")
    parser.add_argument('--build-chromium-tests', nargs='*', metavar='TARGET', help="Chromium targets to build")
    parser.add_argument('--run-chromium-tests', nargs='*', metavar='SUITE[:FILTER]', help="Chromium tests to run")
    parser.add_argument('--gtest_filter', help="Global gtest_filter for Chromium tests")
    parser.add_argument('--no-sandbox', action='store_true', help="Add --no-sandbox to Chromium tests")
    parser.add_argument('--test-launcher-timeout', type=int, default=600, help="Timeout for test launcher")

    args = parser.parse_args()
    print(f"Running tests for platform: {args.platform}, Output dir: {args.output_dir}")
    mock_env = get_env_with_mock_tools()
    print(f"Using PATH: {mock_env.get('PATH')}")

    results = {}; overall_success = True

    if not args.skip_custom_scripts:
        print("\n--- Running Custom Test Scripts ---")
        script_dir = os.path.join(PROJECT_ROOT, 'scripts')
        cmd = []
        if args.platform in ['linux', 'darwin']:
            custom_script_path = os.path.join(script_dir, 'test-hensurf.sh')
            try: os.chmod(custom_script_path, 0o755)
            except OSError as e: print(f"Warning: Could not chmod {custom_script_path}: {e}")
            cmd = ['bash', custom_script_path]
        elif args.platform == 'windows':
            custom_script_path = os.path.join(script_dir, 'test-hensurf.ps1')
            cmd = ['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', custom_script_path]

        if cmd and os.path.exists(custom_script_path):
            success = run_command(cmd, working_dir=PROJECT_ROOT, timeout_seconds=args.test_launcher_timeout, env=mock_env)
            results['custom_tests'] = success;
            if not success: overall_success = False
        else:
            print(f"Custom test script not found for {args.platform} at {custom_script_path if 'custom_script_path' in locals() else 'N/A'}")
            results['custom_tests'] = False; overall_success = False
    else: print("\n--- Skipping Custom Test Scripts ---")

    if args.build_chromium_tests:
        print("\n--- Building Chromium Test Suites ---")
        for suite in args.build_chromium_tests:
            print(f"Building: {suite}")
            build_cmd = ['autoninja', '-C', args.output_dir, suite]
            success = run_command(build_cmd, working_dir=HENSURF_SRC_DIR, env=mock_env)
            results[f'build_{suite}'] = success
            if not success: overall_success = False
    else: print("\n--- Skipping Build of Chromium Test Suites ---")

    if args.run_chromium_tests:
        print("\n--- Running Chromium Test Suites ---")
        for test_spec in args.run_chromium_tests:
            suite, specific_gtest_filter = test_spec.split(':', 1) if ':' in test_spec else (test_spec, args.gtest_filter)
            executable_path = os.path.join(args.output_dir, suite)
            if args.platform == 'windows': executable_path += ".exe"

            if not os.path.exists(executable_path):
                print(f"Test executable not found: {executable_path}. Skipping {suite}.")
                results[f'run_{suite}_{specific_gtest_filter or "all"}'] = False; overall_success = False
                continue

            test_cmd = [executable_path]
            if specific_gtest_filter: test_cmd.append(f'--gtest_filter={specific_gtest_filter}')
            test_cmd.extend(['--test-launcher-bot-mode', f'--test-launcher-timeout={args.test_launcher_timeout * 1000}'])
            if args.no_sandbox: test_cmd.append('--no-sandbox')

            final_run_cmd = []
            if args.platform == 'linux' and suite not in ['unit_tests', 'base_unittests']: # Assuming these don't need display
                xvfb_check = subprocess.run(['which', 'xvfb-run'], capture_output=True, text=True, env=mock_env)
                if xvfb_check.returncode == 0:
                    final_run_cmd.extend(['xvfb-run', '-a']); final_run_cmd.extend(test_cmd)
                else:
                    print("xvfb-run not found, attempting to run test without it."); final_run_cmd.extend(test_cmd)
            else:
                final_run_cmd.extend(test_cmd)

            success = run_command(final_run_cmd, working_dir=HENSURF_SRC_DIR, timeout_seconds=args.test_launcher_timeout + 60, env=mock_env)
            results[f'run_{suite}_{specific_gtest_filter or "all"}'] = success
            if not success: overall_success = False
    else: print("\n--- Skipping Run of Chromium Test Suites ---")

    print("\n--- Test Summary ---")
    if not results: print("No tests were run.")
    else:
        for test_name, passed in results.items(): print(f"{test_name}: {'✅ PASSED' if passed else '❌ FAILED'}")

    if overall_success and results: print("\n🎉 All executed tests passed!"); sys.exit(0)
    elif not results: sys.exit(0)
    else: print("\n⚠️ Some tests failed."); sys.exit(1)

if __name__ == '__main__':
    try:
        current_script_path = os.path.abspath(__file__)
        if platform.system() != "Windows": os.chmod(current_script_path, 0o755)
    except OSError as e: print(f"Warning: Could not chmod {current_script_path}: {e}")
    main()
```

## 4. New Test Case: Default Homepage (`about:blank`)
_(Snippets for test-hensurf.sh and test-hensurf.ps1 remain the same as previous version of this file)_
...

## 5. Assumptions and Challenges
_(Notes remain largely the same as previous version of this file)_
...

## 6. Simulation of `run_all_tests.py` and Analysis (Subtask 8)

This section details the simulated execution of `run_all_tests.py` across different platforms using mock test files.

**Mock `browser_tests` Executable Setup (in `chromium/src/out/HenSurf/`)**:
A mock bash script named `browser_tests` (and `browser_tests.exe` for Windows sim) was created. It simulates GTest output and can produce a passing or failing result based on the `--gtest_filter` argument.
Content of mock `browser_tests`:
```bash
#!/bin/bash
echo "Mock browser_tests invoked with arguments: $@"
echo "[==========] Running 1 test from 1 test suite."
echo "[----------] Global test environment set-up."
# ... (logic to handle different filters and exit codes, as created in Subtask 8) ...
# For brevity, not repeating the full mock script here.
# Key behaviors:
# --gtest_filter=AboutBrowserTest.ShowAboutUI -> PASSED, exit 0
# --gtest_filter=AboutBrowserTest.FailingTestExample -> FAILED, exit 1
# No filter or other filters -> PASSED (simulating one default test passing) or 0 tests run.
```

**Simulation Commands and Analysis**:

*   **Linux Simulation**:
    *   `python3 scripts/run_all_tests.py --platform linux`
        *   **Output Snippet**: Shows `test-hensurf.sh` failing (due to missing `chrome` binary - expected for mock env). Overall result: FAILED.
        *   **Analysis**: Correctly calls bash script.
    *   `python3 scripts/run_all_tests.py --platform linux --run-chromium-tests browser_tests:AboutBrowserTest.ShowAboutUI --no-sandbox`
        *   **Output Snippet**: `test-hensurf.sh` fails. `xvfb-run not found` warning. Mock `browser_tests` for `ShowAboutUI` "passes". Overall result: FAILED (due to custom script).
        *   **Analysis**: Correctly warns for `xvfb-run`, runs browser_tests, passes filter.
    *   `python3 scripts/run_all_tests.py --platform linux --run-chromium-tests browser_tests:AboutBrowserTest.FailingTestExample --no-sandbox`
        *   **Output Snippet**: `test-hensurf.sh` fails. Mock `browser_tests` for `FailingTestExample` "fails". Overall result: FAILED.
        *   **Analysis**: Correctly reports failure from mock `browser_tests`.

*   **macOS Simulation**:
    *   `python3 scripts/run_all_tests.py --platform darwin`
        *   **Output Snippet**: `test-hensurf.sh` fails. Overall result: FAILED.
        *   **Analysis**: Correctly calls bash script.
    *   `python3 scripts/run_all_tests.py --platform darwin --run-chromium-tests browser_tests:AboutBrowserTest.ShowAboutUI --no-sandbox`
        *   **Output Snippet**: `test-hensurf.sh` fails. Mock `browser_tests` for `ShowAboutUI` "passes". `xvfb-run` is NOT mentioned (correct for macOS). Overall result: FAILED.
        *   **Analysis**: Correct platform behavior regarding `xvfb-run`.

*   **Windows Simulation**:
    *   `python3 scripts/run_all_tests.py --platform windows`
        *   **Output Snippet**: Fails to run `test-hensurf.ps1` with `No such file or directory: 'powershell.exe'` (expected in Linux sandbox). Overall result: FAILED.
        *   **Analysis**: Correctly attempts to call PowerShell script.
    *   `python3 scripts/run_all_tests.py --platform windows --skip-custom-scripts --run-chromium-tests browser_tests:AboutBrowserTest.ShowAboutUI --no-sandbox`
        *   **Output Snippet**: Skips custom scripts. Finds and runs mock `browser_tests.exe` (after it was created as a copy of `browser_tests`). Test "passes". Overall result: PASSED.
        *   **Analysis**: Correctly uses `.exe` suffix, skips `xvfb-run`. Shows the runner can report overall success if only successful tests are run.

**Overall Analysis of `run_all_tests.py`**:
*   The script correctly identifies the platform and attempts to run the appropriate custom script.
*   The `--skip-custom-scripts` flag works as expected.
*   The `--run-chromium-tests` flag correctly parses the suite and filter.
*   It handles the `.exe` suffix for Windows test executables.
*   It correctly attempts to use `xvfb-run` only on Linux for relevant tests and warns if not found.
*   The aggregation of PASS/FAIL status works, leading to a correct final exit code (simulated by observing "⚠️ Some tests failed" or "🎉 All executed tests passed!").
*   The `PATH` modification for mock tools is correctly applied.

The main limitations were due to the sandbox environment (missing `powershell.exe`, missing actual `chrome` binary for custom scripts to pass fully). The `run_all_tests.py` script itself seems robust for its designed purpose.
