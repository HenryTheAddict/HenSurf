import os
import platform
import subprocess
import argparse
import sys

# Try to determine the absolute path to the root of the HenSurf project.
# This script is in /app/scripts/run_all_tests.py
# Project root is /app
# Chromium source is /app/chromium/src
# Output dir is /app/chromium/src/out/HenSurf
# Custom test scripts are in /app/scripts/
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, '..'))
HENSURF_SRC_DIR = os.path.join(PROJECT_ROOT, 'chromium', 'src')
HENSURF_OUT_DIR_DEFAULT = os.path.join(HENSURF_SRC_DIR, 'out', 'HenSurf')

# Path to mock depot_tools and other tools for the sandbox environment
MOCK_TOOLS_DIR = os.path.join(PROJECT_ROOT, 'tmp_mocks')

def get_env_with_mock_tools():
    """Returns a modified environment dictionary with mock tools in PATH."""
    env = os.environ.copy()
    env['PATH'] = MOCK_TOOLS_DIR + os.pathsep + env.get('PATH', '')
    # Add depot_tools_mock if it contains other necessary tools like gclient (though not used by this script directly)
    depot_tools_mock_dir = os.path.join(PROJECT_ROOT, 'depot_tools_mock')
    env['PATH'] = depot_tools_mock_dir + os.pathsep + env['PATH']
    return env

def run_command(cmd_list, working_dir=None, timeout_seconds=300, env=None, check_exit_code=True):
    print(f"Executing: {' '.join(cmd_list)} in {working_dir or os.getcwd()}")
    try:
        # If env is None, the current environment is inherited, which is usually what we want
        # unless we need to specifically add mock tools to PATH.
        process_env = env if env else os.environ.copy()

        process = subprocess.run(cmd_list, cwd=working_dir, capture_output=True, text=True,
                                 timeout=timeout_seconds, env=process_env, check=False) # check=False to handle manually

        stdout_lines = process.stdout.splitlines()
        stderr_lines = process.stderr.splitlines()

        print("STDOUT:")
        for line in stdout_lines:
            print(line)

        if stderr_lines:
            print("STDERR:")
            for line in stderr_lines:
                print(line)

        if check_exit_code and process.returncode != 0:
            print(f"Command FAILED with exit code {process.returncode}.")
            return False
        else:
            # If not checking exit code, or if exit code is 0, consider it a logical success for this function
            print(f"Command finished with exit code {process.returncode}.")
            return True # For build steps, even a non-zero might be okay if we want to see test results
                       # but for tests themselves, non-zero is a failure.
                       # The caller should decide. For now, this function just reports execution.
                       # Let's refine: True if returncode is 0, False otherwise if check_exit_code is True.
                       # If check_exit_code is False, always return True (command ran).
            # Refined logic:
            if check_exit_code:
                if process.returncode == 0:
                    print("Command SUCCEEDED.")
                    return True
                else:
                    # print(f"Command FAILED with exit code {process.returncode}.") # Already printed
                    return False
            return True # Command ran, ignore exit code

    except subprocess.TimeoutExpired:
        print(f"Command timed out after {timeout_seconds} seconds.")
        return False
    except Exception as e:
        print(f"Error running command: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="HenSurf Cross-Platform Test Runner")
    parser.add_argument('--platform', default=platform.system().lower(), choices=['linux', 'windows', 'darwin'], help="OS platform (default: auto-detected)")
    parser.add_argument('--output-dir', default=HENSURF_OUT_DIR_DEFAULT, help="Chromium output directory (e.g., out/HenSurf)")
    parser.add_argument('--skip-custom-scripts', action='store_true', help="Skip running test-hensurf.sh/ps1")
    parser.add_argument('--build-chromium-tests', nargs='*', metavar='TARGET', help="List of Chromium test suites/targets to build (e.g., browser_tests unit_tests)")
    parser.add_argument('--run-chromium-tests', nargs='*', metavar='SUITE[:FILTER]', help="List of Chromium test suites to run, with optional gtest_filter (e.g., browser_tests:BrowserTest.Sanity)")
    parser.add_argument('--gtest_filter', help="Global gtest_filter for all --run-chromium-tests suites if not specified per suite")
    parser.add_argument('--no-sandbox', action='store_true', help="Add --no-sandbox to Chromium test runs")
    parser.add_argument('--test-launcher-timeout', type=int, default=600, help="Timeout in seconds for test launcher commands.")


    args = parser.parse_args()
    print(f"Running tests for platform: {args.platform}")
    print(f"Output directory: {args.output_dir}")

    # Get environment with mock tools in PATH (important for autoninja)
    mock_env = get_env_with_mock_tools()
    print(f"Using PATH: {mock_env.get('PATH')}")


    results = {}
    overall_success = True

    # 1. Run Custom Test Scripts (test-hensurf.sh/ps1)
    if not args.skip_custom_scripts:
        print("\n--- Running Custom Test Scripts ---")
        custom_script_path = ""
        cmd = []
        # Scripts are in PROJECT_ROOT/scripts/
        script_dir = os.path.join(PROJECT_ROOT, 'scripts')

        if args.platform == 'linux' or args.platform == 'darwin':
            custom_script_path = os.path.join(script_dir, 'test-hensurf.sh')
            # Ensure it's executable - this might fail in sandbox if not already set
            try:
                os.chmod(custom_script_path, 0o755)
            except OSError as e:
                print(f"Warning: Could not chmod {custom_script_path}: {e}")

            cmd = ['bash', custom_script_path]
        elif args.platform == 'windows':
            custom_script_path = os.path.join(script_dir, 'test-hensurf.ps1')
            cmd = ['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', custom_script_path]

        if cmd and os.path.exists(custom_script_path):
            # Custom scripts are run from the project root, as they might have relative paths like `chromium/src/...`
            success = run_command(cmd, working_dir=PROJECT_ROOT, timeout_seconds=args.test_launcher_timeout, env=mock_env)
            results['custom_tests'] = success
            if not success: overall_success = False
        else:
            print(f"Custom test script not found for {args.platform} at {custom_script_path}")
            results['custom_tests'] = False
            overall_success = False
    else:
        print("\n--- Skipping Custom Test Scripts ---")

    # 2. Build Chromium Test Suites (Optional)
    if args.build_chromium_tests:
        print("\n--- Building Chromium Test Suites ---")
        for suite in args.build_chromium_tests:
            print(f"Building: {suite}")
            build_cmd = ['autoninja', '-C', args.output_dir, suite]
            success = run_command(build_cmd, working_dir=HENSURF_SRC_DIR, env=mock_env) # autoninja needs to run from src
            results[f'build_{suite}'] = success
            if not success:
                print(f"Stopping early because build of {suite} failed.")
                overall_success = False
                # Decide if to exit or continue based on requirements for real runs
    else:
        print("\n--- Skipping Build of Chromium Test Suites ---")


    # 3. Run Chromium Test Suites (Optional)
    if args.run_chromium_tests:
        print("\n--- Running Chromium Test Suites ---")
        for test_spec in args.run_chromium_tests:
            suite, specific_gtest_filter = test_spec.split(':', 1) if ':' in test_spec else (test_spec, args.gtest_filter)

            executable_path = os.path.join(args.output_dir, suite)
            if args.platform == 'windows':
                executable_path += ".exe"

            if not os.path.exists(executable_path):
                print(f"Test executable not found: {executable_path}. Skipping {suite}.")
                results[f'run_{suite}_{specific_gtest_filter or "all"}'] = False
                overall_success = False
                continue

            test_cmd = [executable_path]
            if specific_gtest_filter:
                test_cmd.append(f'--gtest_filter={specific_gtest_filter}')

            # Common flags for Chromium tests
            test_cmd.append('--test-launcher-bot-mode')
            test_cmd.append(f'--test-launcher-timeout={args.test_launcher_timeout * 1000}') # ms for test_launcher_timeout
            if args.no_sandbox:
                test_cmd.append('--no-sandbox')

            final_run_cmd = []
            if args.platform == 'linux' and suite not in ['unit_tests', 'base_unittests']: # unit_tests usually don't need X display
                # Check if xvfb-run is available
                xvfb_check_process = subprocess.run(['which', 'xvfb-run'], capture_output=True, text=True, env=mock_env)
                if xvfb_check_process.returncode == 0:
                    final_run_cmd.extend(['xvfb-run', '-a']) # Auto-servernum
                    final_run_cmd.extend(test_cmd)
                else:
                    print("xvfb-run not found, attempting to run test without it. May fail if UI is needed.")
                    final_run_cmd.extend(test_cmd)
            else:
                final_run_cmd.extend(test_cmd)

            # Tests are run from src dir typically, as they might load resources relative to it or out/
            success = run_command(final_run_cmd, working_dir=HENSURF_SRC_DIR, timeout_seconds=args.test_launcher_timeout + 60, env=mock_env)
            results[f'run_{suite}_{specific_gtest_filter or "all"}'] = success
            if not success: overall_success = False
    else:
        print("\n--- Skipping Run of Chromium Test Suites ---")

    # 4. Summarize Results
    print("\n--- Test Summary ---")
    if not results:
        print("No tests were run.")
    else:
        for test_name, passed in results.items():
            status = "✅ PASSED" if passed else "❌ FAILED"
            print(f"{test_name}: {status}")

    if overall_success and results: # Ensure some tests actually ran
        print("\n🎉 All executed tests passed!")
        sys.exit(0)
    elif not results: # No tests ran, not a failure but not a success either
        sys.exit(0)
    else:
        print("\n⚠️ Some tests failed.")
        sys.exit(1)

if __name__ == '__main__':
    # Set execute permissions for this script itself, primarily for non-Windows.
    try:
        current_script_path = os.path.abspath(__file__)
        if platform.system() != "Windows":
            os.chmod(current_script_path, 0o755)
    except OSError as e:
        print(f"Warning: Could not chmod {current_script_path}: {e}")
    main()
