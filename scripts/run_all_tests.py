"""
Runs various tests for the HenSurf project.

This script can execute custom test scripts (shell/powershell) and specific
Chromium test suites like browser_tests and unit_tests. It provides options
to specify the platform, output directory, and test filters.
It also includes mockups for certain tools if run in a sandboxed environment.
"""
import os
import platform
import subprocess  # nosec B404
import argparse
import sys

# Try to determine the absolute path to the root of the HenSurf project.
# This script is in /app/scripts/run_all_tests.py
# Project root is /app
# Chromium source is /app/src/chromium
# Output dir is /app/src/chromium/out/HenSurf
# Custom test scripts are in /app/scripts/
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, '..'))
HENSURF_SRC_DIR = os.path.join(PROJECT_ROOT, 'src', 'chromium')
HENSURF_OUT_DIR_DEFAULT = os.path.join(
    HENSURF_SRC_DIR, 'out', 'HenSurf'
)

# Path to mock depot_tools and other tools for the sandbox environment
MOCK_TOOLS_DIR = os.path.join(PROJECT_ROOT, 'tmp_mocks')


def get_env_with_mock_tools():
    """
    Returns a modified environment dictionary with mock tools in PATH.

    This is used to ensure that scripts like autoninja can find their
    dependencies (like a mock gclient) when running in a controlled
    or sandboxed environment.
    """
    env = os.environ.copy()
    current_path = env.get('PATH', '')
    env['PATH'] = f"{MOCK_TOOLS_DIR}{os.pathsep}{current_path}"
    # Add depot_tools_mock if it contains other necessary tools like gclient
    # (though not used by this script directly)
    depot_tools_mock_dir = os.path.join(PROJECT_ROOT, 'depot_tools_mock')
    env['PATH'] = depot_tools_mock_dir + os.pathsep + env['PATH']
    return env


def run_command(cmd_list, working_dir=None, timeout_seconds=300, env=None):
    """
    Executes a shell command and captures its output.

    Args:
        cmd_list (list[str]): The command and its arguments as a list of strings.
        working_dir (str, optional): The directory to execute the command in.
            Defaults to the current working directory.
        timeout_seconds (int, optional): Timeout for the command in seconds.
            Defaults to 300.
        env (dict, optional): Environment variables to use for the command.
            Defaults to the current process environment.

    Returns:
        bool: True if the command executed successfully, False otherwise
              (e.g., non-zero exit, timeout, or other execution error).
    """
    cmd_str = ' '.join(cmd_list)
    wd_str = working_dir or os.getcwd()
    print(f"Executing: {cmd_str} in {wd_str}")  # noqa: E501
    try:
        # If env is None, the current environment is inherited, which is usually what we want
        # unless we need to specifically add mock tools to PATH.

        process = subprocess.run(  # nosec B603
            cmd_list,
            cwd=working_dir,
            capture_output=True,
            text=True,
            check=True,
            timeout=timeout_seconds,
            env=env or os.environ.copy()  # noqa: E501
        )
        stdout_lines = process.stdout.splitlines() if process.stdout else []
        stderr_lines = process.stderr.splitlines() if process.stderr else []

        print("STDOUT:")
        for line in stdout_lines:
            print(line)

        if stderr_lines:
            print("STDERR:")
            for line in stderr_lines:
                print(line)
        # If check=True is used, CalledProcessError will be raised for non-zero exit codes.
        # The stdout/stderr can be accessed from the exception object.
        # Explicitly return True on command success (if check=True and no exception)
        return True

    except subprocess.CalledProcessError as e:
        print(f"Command FAILED with exit code {e.returncode}.")  # noqa: E501
        # stdout and stderr are attributes of the exception object
        stdout_from_error = e.stdout.splitlines() if e.stdout else []  # noqa: E501
        stderr_from_error = e.stderr.splitlines() if e.stderr else []

        print("STDOUT (from CalledProcessError):")  # noqa: E501
        for line in stdout_from_error:
            print(line)
        print("STDERR (from CalledProcessError):")
        for line in stderr_from_error:
            print(line)
        return False
    except subprocess.TimeoutExpired:
        print(f"Command timed out after {timeout_seconds} seconds.")
        return False
    except FileNotFoundError as e:
        print(f"Error: Command not found: {cmd_list[0]}. Details: {e}")  # noqa: E501 # pylint: disable=line-too-long
        return False
    except OSError as e:  # Catching OSError which is a base for many execution errors
        print(f"Error executing command: {cmd_list[0]}. Details: {e}")  # noqa: E501 # pylint: disable=line-too-long
        return False
    except Exception as e:  # pylint: disable=broad-except
        print(  # noqa: E501
            f"An unexpected error occurred while running command: {cmd_list[0]}. Details: {e}") # pylint: disable=line-too-long
        return False


def _run_custom_tests(args, mock_env):
    """Runs custom test scripts (e.g., test-hensurf.sh/ps1)."""
    print("\n--- Running Custom Test Scripts ---")
    custom_script_path = ""
    cmd = []
    script_dir = os.path.join(PROJECT_ROOT, 'scripts')
    current_results = {}
    success_flag = True

    if args.platform in ['linux', 'darwin']:
        custom_script_path = os.path.join(script_dir, 'test-hensurf.sh')
        try:
            # pylint: disable=C0321
            os.chmod(custom_script_path, 0o755)  # nosec B103
        except OSError as e:
            print(f"Warning: Could not chmod {custom_script_path}: {e}")
        cmd = ['bash', custom_script_path]
    elif args.platform == 'windows':
        custom_script_path = os.path.join(script_dir, 'test-hensurf.ps1')
        cmd = [
            'powershell.exe', '-ExecutionPolicy', 'Bypass',
            '-File', custom_script_path
        ]

    if cmd and os.path.exists(custom_script_path):
        success = run_command(
            cmd, working_dir=PROJECT_ROOT,
            timeout_seconds=args.test_launcher_timeout, env=mock_env
        )
        current_results['custom_tests'] = success
        if not success:
            success_flag = False
    else:
        print(
            f"Custom test script not found for {args.platform} at {custom_script_path}")  # noqa: E501 # pylint: disable=line-too-long
        current_results['custom_tests'] = False
        success_flag = False
    return success_flag, current_results


def _build_chromium_suites(args, mock_env):
    """Builds specified Chromium test suites."""
    print("\n--- Building Chromium Test Suites ---")
    current_results = {}
    success_flag = True
    for suite in args.build_chromium_tests:
        print(f"Building: {suite}")
        build_cmd = ['autoninja', '-C', args.output_dir, suite]
        success = run_command(
            build_cmd, working_dir=HENSURF_SRC_DIR, env=mock_env  # noqa: E501
        )
        current_results[f'build_{suite}'] = success
        if not success:
            print(f"Stopping early because build of {suite} failed.")
            success_flag = False
            # Potentially break here if one build failure means we can't proceed
            # For now, it will try all builds and report all failures.
    return success_flag, current_results


def _run_chromium_suites(args, mock_env):
    """Runs specified Chromium test suites."""
    print("\n--- Running Chromium Test Suites ---")
    current_results = {}
    success_flag = True
    for test_spec in args.run_chromium_tests:
        if ':' in test_spec:
            suite, specific_gtest_filter = test_spec.split(':', 1)
        else:
            suite, specific_gtest_filter = test_spec, args.gtest_filter
        result_key = f'run_{suite}'

        executable_path = os.path.join(args.output_dir, suite)
        if args.platform == 'windows':
            executable_path += ".exe"

        if not os.path.exists(executable_path):
            print(
                f"Test executable not found: {executable_path}. "  # noqa: E501 # pylint: disable=line-too-long
                f"Skipping {suite}."
            )
            current_results[result_key] = False
            success_flag = False
            continue

        test_cmd = [executable_path]
        if specific_gtest_filter:
            test_cmd.append(f'--gtest_filter={specific_gtest_filter}')

        test_cmd.append('--test-launcher-bot-mode')
        test_cmd.append(
            f'--test-launcher-timeout={args.test_launcher_timeout * 1000}'  # noqa: E501 # pylint: disable=line-too-long
        )
        if args.no_sandbox:
            test_cmd.append('--no-sandbox')

        final_run_cmd = []
        if args.platform in ['linux', 'darwin'] and suite in [
            'browser_tests', 'unit_tests'
        ]:
            xvfb_check_process = subprocess.run(  # nosec B603 B607
                ['which', 'xvfb-run'], capture_output=True, text=True, check=False  # noqa: E501 # pylint: disable=line-too-long
            )
            if xvfb_check_process.returncode == 0:
                final_run_cmd.extend(['xvfb-run', '-a'])
                final_run_cmd.extend(test_cmd)
            else:
                print(
                    "xvfb-run not found, attempting to run test without it. "  # noqa: E501 # pylint: disable=line-too-long
                    "May fail if UI is needed."
                )
                final_run_cmd.extend(test_cmd)
        else:
            final_run_cmd.extend(test_cmd)

        success = run_command(
            final_run_cmd, working_dir=HENSURF_SRC_DIR,
            timeout_seconds=args.test_launcher_timeout + 60, env=mock_env
        )
        current_results[result_key] = success
        if not success:
            success_flag = False
    return success_flag, current_results


def _summarize_and_exit(results, overall_success):
    """Prints test summary and exits with appropriate code."""
    print("\n--- Test Summary ---")
    if not results:
        print("No tests were run.")
    else:
        for test_name, passed in results.items():
            status = "✅ PASSED" if passed else "❌ FAILED"
            print(f"{test_name}: {status}")

    if overall_success and results:
        print("\n🎉 All executed tests passed!")
        sys.exit(0)
    elif not results:
        print("No tests were specified or run.")
        sys.exit(0)
    else:
        print("\n⚠️ Some tests failed.")
        sys.exit(1)


def main():
    """
    Main function to parse arguments and run tests.
    Orchestrates the test execution process based on command-line arguments.
    """
    desc = "Test Runner"
    desc = """Comprehensive Test Runner for HenSurf Browser.
    This script can execute custom test scripts (shell/powershell)
    and specific Chromium test suites like browser_tests and unit_tests.
    It provides options to specify the platform, output directory,
    and test filters. It also includes mockups for certain tools
    if run in a sandboxed environment.
    """
    parser = argparse.ArgumentParser(
        description=desc,
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        '--platform', default=platform.system().lower(),
        choices=['linux', 'windows', 'darwin'],
        help="OS platform (default: auto-detected)"
    )
    parser.add_argument(
        '--output-dir', default=HENSURF_OUT_DIR_DEFAULT,
        help="Chromium output directory (e.g., out/HenSurf)"
    )
    parser.add_argument(
        '--skip-custom-scripts', action='store_true',
        help="Skip running test-hensurf.sh/ps1"
    )
    parser.add_argument(
        '--build-chromium-tests', nargs='*', metavar='TARGET',
        help="List of Chromium test suites/targets to build "  # noqa: E501 # pylint: disable=line-too-long
             "(e.g., browser_tests unit_tests)"
    )
    parser.add_argument(
        '--run-chromium-tests', nargs='*', metavar='SUITE[:FILTER]',
        help="List of Chromium test suites to run, with optional gtest_filter "  # noqa: E501 # pylint: disable=line-too-long
             "(e.g., browser_tests:BrowserTest.Sanity)"
    )
    parser.add_argument(
        '--gtest_filter',
        help="Global gtest_filter for all --run-chromium-tests suites "  # noqa: E501 # pylint: disable=line-too-long
             "if not specified per suite"
    )
    parser.add_argument(
        '--no-sandbox', action='store_true',
        help="Add --no-sandbox to Chromium test runs"
    )
    parser.add_argument(
        '--test-launcher-timeout', type=int, default=600,
        help="Timeout in seconds for test launcher commands."
    )
    parser.add_argument(
        '--list-tests', action='store_true',
        help="Print a list of known test targets/suites and exit."
    )

    args = parser.parse_args()

    if args.list_tests:
        print("Known test targets/suites for --build-chromium-tests and --run-chromium-tests:")
        print("  - custom_scripts (handled by --skip-custom-scripts flag instead of these options)")
        print("  - browser_tests")
        print("  - unit_tests")
        print("  - interactive_ui_tests")
        print("  - components_unittests")
        print("  - services_unittests")
        print("  - content_unittests")
        print("  - media_unittests")
        print("  - views_unittests")
        print("  - extensions_unittests")
        print("  - (and many others available in a full Chromium checkout)")
        print("\nUse specific suite names with --build-chromium-tests or --run-chromium-tests.")
        print("For --run-chromium-tests, you can also specify a filter, e.g., browser_tests:BrowserTest.Sanity")
        sys.exit(0)

    print(f"Running tests for platform: {args.platform}")
    print(f"Output directory: {args.output_dir}")

    # Get environment with mock tools in PATH (important for autoninja)
    mock_env = get_env_with_mock_tools()
    print(f"Using PATH: {mock_env.get('PATH')}")

    results = {}
    overall_success = True

    # 1. Run Custom Test Scripts
    if not args.skip_custom_scripts:
        custom_success, custom_results = _run_custom_tests(args, mock_env)
        results.update(custom_results)
        if not custom_success:
            overall_success = False
    else:
        print("\n--- Skipping Custom Test Scripts ---")

    # 2. Build Chromium Test Suites (Optional)
    if args.build_chromium_tests:
        build_success, build_results = _build_chromium_suites(args, mock_env)
        results.update(build_results)
        if not build_success:
            overall_success = False
            # If a build fails, we might not want to proceed to running tests.
            # For now, the script will continue and try to run what it can.
    else:
        print("\n--- Skipping Build of Chromium Test Suites ---")

    # 3. Run Chromium Test Suites (Optional)
    # Only proceed if builds were successful or not attempted
    if args.run_chromium_tests and (not args.build_chromium_tests or overall_success):  # noqa: E501 # pylint: disable=line-too-long
        run_success, run_results = _run_chromium_suites(args, mock_env)
        results.update(run_results)
        if not run_success:
            overall_success = False
    elif args.run_chromium_tests and args.build_chromium_tests and not overall_success:  # noqa: E501 # pylint: disable=line-too-long
        print(
            "\n--- Skipping Run of Chromium Test Suites due to previous build failures ---")  # noqa: E501 # pylint: disable=line-too-long
    else:
        print("\n--- Skipping Run of Chromium Test Suites ---")

    # 4. Summarize Results
    _summarize_and_exit(results, overall_success)


if __name__ == '__main__':
    # Set execute permissions for this script itself, primarily for non-Windows.
    try:
        current_script_path = os.path.abspath(__file__)
        if platform.system() != "Windows":
            os.chmod(current_script_path, 0o755)  # nosec B103
    except OSError as e:
        print(f"Warning: Could not chmod {current_script_path}: {e}")
    main()
