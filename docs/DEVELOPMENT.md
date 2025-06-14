# HenSurf Development Guide

## Table of Contents

- [Development Environment Setup](#development-environment-setup)
  - [Prerequisites](#prerequisites)
  - [Quick Setup](#quick-setup)
- [Development Workflow](#development-workflow)
  - [Making Changes](#making-changes)
  - [Creating Patches](#creating-patches)
  - [Build Configurations](#build-configurations)
- [Debugging](#debugging)
  - [Common Issues](#common-issues)
  - [Debugging Tools](#debugging-tools)
- [Testing](#testing)
  - [Manual Testing](#manual-testing)
  - [Automated Testing](#automated-testing)
- [Code Style](#code-style)
  - [Chromium Style Guide](#chromium-style-guide)
  - [HenSurf Conventions](#hensurf-conventions)
  - [Code Review Checklist](#code-review-checklist)
- [Performance Optimization](#performance-optimization)
  - [Build Performance](#build-performance)
  - [Runtime Performance](#runtime-performance)
- [Release Process](#release-process)
  - [Version Management](#version-management)
  - [Build Release](#build-release)
  - [Distribution](#distribution)
- [Contributing Guidelines](#contributing-guidelines)
  - [Pull Request Process](#pull-request-process)
  - [Issue Reporting](#issue-reporting)
  - [Security](#security)
- [Resources](#resources)
  - [Documentation](#documentation)
  - [Tools](#tools)
  - [Community](#community)

This guide covers development workflows, debugging, and contribution guidelines for HenSurf.

## Development Environment Setup

### Prerequisites

- **macOS 10.15+** (Catalina or later)
  - Ensure the Xcode license is accepted (run `sudo xcodebuild -license accept` if prompted by `install-deps.sh` or if builds fail with license errors).
  - For better build performance, consider excluding your HenSurf project directory from Spotlight indexing (System Settings -> Siri & Spotlight -> Spotlight Privacy...). `install-deps.sh` will remind you of this.
- **Xcode Command Line Tools**: `install-deps.sh` will help install these if missing.
- **16GB+ RAM** (32GB recommended)
- **100GB+ free disk space** (more might be needed for ccache and multiple builds)
- **Fast internet connection** (for initial source download)

### Quick Setup

This guide assumes you have already cloned the HenSurf repository and are in its root directory.

```bash
# 1. Install dependencies (guides through Python, Git, Ninja, depot_tools, etc.)
./scripts/install-deps.sh

# 2. Fetch Chromium source code (can take 30-60+ minutes and ~100GB)
./scripts/fetch-chromium.sh
# This script now offers an optional enhanced sync for full history.

# 3. Apply HenSurf customizations (patches, branding files, code generation)
./scripts/apply-patches.sh
# This script orchestrates applying .patch files and calls setup-logo.sh.

# 4. Build HenSurf (can take 2-8+ hours)
./scripts/interactive_build.sh
# This is the recommended way to build, offering a menu for common targets.
# Alternatively, use ./scripts/build.sh directly for specific configurations.
```

**Note for macOS users**: `install-deps.sh` assists with Homebrew and Xcode Command Line Tools. `interactive_build.sh` or `build.sh` (when run without target env vars) will default to your Mac's native architecture (Intel x64 or Apple Silicon arm64). `setup-logo.sh` (called by `apply-patches.sh`) will attempt to create `.icns` files using `iconutil`.

**Note for Windows users**: Ensure you are using Git Bash for all `.sh` scripts. `install-deps.sh` will guide on Visual Studio, Python, Git, and Ninja. `setup-logo.sh` (called by `apply-patches.sh`) will attempt to create `.ico` files using ImageMagick's `convert` if available.

## Development Workflow

### Making Changes

1. **Modify Source Code**
   ```bash
   cd src/chromium
   # Edit files as needed
   ```

2. **Incremental Build**
   ```bash
   autoninja -C out/HenSurf chrome
   ```

3. **Test Changes**
   ```bash
   ./out/HenSurf/chrome --user-data-dir=/tmp/hensurf-test
   ```

### Creating Patches

Patches are how HenSurf modifies the Chromium source code. A patch file is a text file that lists the differences between the original Chromium code and the modified version for a specific feature or fix.

**1. Identify Changes for Your Patch:**
   - Before creating a patch, ensure your changes are focused. A single patch should ideally address a single, logical change (e.g., remove one specific bloatware feature, fix one bug). Avoid bundling unrelated changes into one patch.
   - Navigate to the Chromium source directory: `cd src/chromium`.
   - Use `git status` to see which files you've modified.
   - Use `git add <file_path>` for each file you want to include in the patch. This stages the changes for commit (though we are generating a diff, staging helps `git diff --staged`).

**2. Generate the Patch File:**
   - Once you have staged the changes for your specific feature or fix, generate the patch file using `git diff`.
   - It's crucial to be in the `src/chromium` directory.
   - The output of `git diff --staged` is what you need for your patch file.
   ```bash
   cd src/chromium
   # Ensure you've staged only the files relevant to this specific patch
   # git add path/to/modified/file1.cc
   # git add path/to/another/modified/file2.h

   # Generate the patch relative to the HenSurf project root
   git diff --staged > ../../src/hensurf/patches/my-new-feature-or-fix.patch
   ```
   - **Naming Convention:** Use a descriptive name for your patch file, like `remove-profile-import-dialog.patch` or `fix-crash-on-settings-page.patch`.

**3. Add Patch to Apply Script:**
   - For your patch to be applied during the HenSurf build process, ensure it's in the `src/hensurf/patches/` directory.
   - The `scripts/apply-patches.sh` script attempts to apply key patches like `remove-ai-features.patch` and `integrate-logo.patch`. If you are adding a new, separate feature patch, you might use `scripts/apply_feature_patches.sh apply your-patch-name` for testing, or integrate it into the main `apply-patches.sh` if it's a core HenSurf modification.
   - Patches are typically applied with `patch -p1` relative to the `src/chromium` directory.

**4. Test Patch Application:**
   - If you've modified `apply-patches.sh` or are testing a feature patch:
   ```bash
   # From the HenSurf project root, after navigating into src/chromium if needed by your test
   # (apply-patches.sh handles its own cd into src/chromium)
   ./scripts/apply-patches.sh
   # or for a specific feature patch:
   # ./scripts/apply_feature_patches.sh apply your-patch-name
   ```
   - If there are issues (`.rej` files created), you may need to regenerate your patch or adjust it for current Chromium source.

**Important Considerations for Patches:**
   - **Atomicity:** Each patch should be as small as possible while addressing a single concern. This makes it easier to review, debug, and manage if Chromium upstream code changes.
   - **Clarity:** Ensure your code changes within the patch are clean and follow the Chromium style guide.
   - **Maintenance:** Patches can break when the underlying Chromium code changes. Be prepared to update your patches when pulling in new versions of Chromium. This is known as "rebasing" or "porting" patches.

### Build Configurations

#### Debug Build
```bash
# Create debug configuration
mkdir -p src/chromium/out/Debug
echo 'is_debug = true' > src/chromium/out/Debug/args.gn
echo 'symbol_level = 2' >> src/chromium/out/Debug/args.gn

# Build debug version
autoninja -C out/Debug chrome
```

#### Release Build
```bash
# Use the default HenSurf configuration
autoninja -C out/HenSurf chrome
```

## Debugging

### Common Issues

#### Build Failures

**Symptom**: Compilation errors
```bash
# Clean build directory
rm -rf src/chromium/out/HenSurf
gn gen src/chromium/out/HenSurf

# Check for missing dependencies
gclient runhooks
```

**Symptom**: Linker errors
```bash
# Increase build parallelism
export NINJA_PARALLEL_JOBS=4
autoninja -C out/HenSurf chrome
```

#### Runtime Issues

**Symptom**: Crashes on startup
```bash
# Run with debugging
./out/HenSurf/chrome --enable-logging --log-level=0 --user-data-dir=/tmp/debug
```

**Symptom**: Missing features
```bash
# Check build configuration
gn args out/HenSurf --list | grep feature_name
```

### Debugging Tools

#### GDB Debugging
```bash
# Debug with GDB
gdb ./out/HenSurf/chrome
(gdb) run --user-data-dir=/tmp/debug
```

#### Chrome DevTools
```bash
# Enable DevTools for browser UI
./out/HenSurf/chrome --enable-browser-side-navigation --enable-features=WebUITabStrip
```

#### Logging
```bash
# Enable verbose logging
./out/HenSurf/chrome --enable-logging --log-level=0 --vmodule=*=1
```

## Testing

### Manual Testing

#### Privacy Features
1. **Search Engine**: Verify DuckDuckGo is default
2. **No Google Services**: Check no Google API calls
3. **No AI Features**: Verify AI suggestions disabled
4. **Telemetry**: Confirm no data collection

#### Functionality Testing
1. **Basic Browsing**: Navigation, tabs, bookmarks
2. **Extensions**: Install and test extensions
3. **Downloads**: File download functionality
4. **Settings**: All settings pages accessible

### Automated Testing

#### Unit Tests
```bash
# Run unit tests
autoninja -C out/HenSurf unit_tests
./out/HenSurf/unit_tests
```

#### Browser Tests
```bash
# Build browser_tests (if not already built)
autoninja -C out/HenSurf browser_tests

# Run browser_tests (example filter)
# Use a specific output directory if your build was not in out/HenSurf
./out/HenSurf/browser_tests --gtest_filter=*Privacy*
# On Linux, this might require xvfb-run if not running in a headless environment already configured.
# e.g., xvfb-run -a ./out/HenSurf/browser_tests --gtest_filter=*Privacy*
```

#### Using `run_all_tests.py`
The `scripts/run_all_tests.py` script provides a unified way to run custom tests, build test suites, and execute them.
```bash
# List available test suites/targets (conceptual)
python3 scripts/run_all_tests.py --list-tests

# Example: Run custom scripts and specific browser tests on Linux
python3 scripts/run_all_tests.py --platform linux --output-dir src/chromium/out/HenSurf-linux-x64 --run-chromium-tests browser_tests:BrowserTest.Sanity
```

#### Performance Tests
```bash
# Build performance test tools (example suite)
autoninja -C out/HenSurf performance_test_suite
# Running performance tests often involves specific harnesses and metrics.
# Refer to Chromium's performance testing documentation for details.
```

## Code Style

### Chromium Style Guide
Follow the [Chromium C++ Style Guide](https://chromium.googlesource.com/chromium/src/+/main/styleguide/c++/c++.md)

### HenSurf Conventions
- Prefix HenSurf-specific code with `hensurf_`
- Use clear, descriptive variable names
- Add comments explaining privacy/security implications
- Document any Google service removals

### Code Review Checklist
- [ ] No new Google API dependencies
- [ ] No AI/ML feature additions
- [ ] Privacy implications documented
- [ ] Performance impact assessed
- [ ] Tests updated/added
- [ ] Documentation updated

## Performance Optimization

### Build Performance

#### Faster Builds
```bash
# Use more CPU cores
export NINJA_PARALLEL_JOBS=$(sysctl -n hw.ncpu)

# Use jumbo builds
echo 'use_jumbo_build = true' >> out/HenSurf/args.gn

# Enable ccache
# On macOS, ccache is installed by ./scripts/install-deps.sh.
# On Linux, ensure ccache is installed separately.
# To enable ccache for your build, add the following to your out/HenSurf/args.gn (or other build directory's args.gn):
#   cc_wrapper = "ccache"
# Then, ensure your ccache is configured (e.g., run `ccache -M 50G` to set max size).
```

#### Incremental Builds
```bash
# Only build changed components
autoninja -C out/HenSurf chrome

# Build specific targets
autoninja -C out/HenSurf //chrome/browser:browser
```

### Runtime Performance

#### Memory Usage
- Monitor with Activity Monitor
- Use `--memory-pressure-off` for testing
- Profile with Instruments.app

#### Startup Time
```bash
# Measure startup time
time ./out/HenSurf/chrome --user-data-dir=/tmp/perf --no-first-run
```

## Release Process

### Version Management

1. **Update Version**
   ```bash
   # Edit version in src/hensurf/branding/BRANDING
   MAJOR=1
   MINOR=1
   BUILD=0
   PATCH=0
   ```

2. **Tag Release**
   ```bash
   git tag -a v1.1.0 -m "HenSurf v1.1.0"
   git push origin v1.1.0
   ```

### Build Release

```bash
# Clean build for release
rm -rf src/chromium/out/HenSurf
./scripts/apply-patches.sh
./scripts/build.sh

# Create installer
autoninja -C src/chromium/out/HenSurf chrome/installer/mac
```

### Distribution

1. **Code Signing** (if available)
   ```bash
   codesign --force --deep --sign "Developer ID" HenSurf.app
   ```

2. **Notarization** (if available)
   ```bash
   xcrun altool --notarize-app --file HenSurf.dmg
   ```

## Contributing Guidelines

### Pull Request Process

1. **Fork Repository**
2. **Create Feature Branch**
   ```bash
   git checkout -b feature/remove-more-bloat
   ```

3. **Make Changes & Commit**
   - Implement your feature or bug fix.
   - Follow the [Code Style](#code-style) guidelines.
   - Add tests for new features or to cover bug fixes.
   - Update documentation if your changes affect usage or architecture.
   - **Write Good Commit Messages:**
     - Your commit messages are crucial for understanding the history of changes.
     - Start with a short, descriptive subject line (e.g., `feat: Add option to disable foobar`, `fix: Correct crash when clicking baz`). Consider using a prefix like `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`.
     - If the subject line isn't enough, leave a blank line and then write a more detailed explanation in the commit body. Explain *what* the change is and *why* you made it.
     - Example:
       ```
       feat: Add option to disable search suggestions in omnibox

       This commit introduces a new preference in the settings page
       (Privacy section) that allows users to disable search
       suggestions that appear in the omnibox dropdown. This enhances
       user privacy by preventing queries from being sent to the default
       search provider until the user explicitly navigates.

       Addresses issue #123.
       ```
   - Commit your changes locally: `git commit -m "Your descriptive commit message"`

4. **Test Changes Thoroughly**
   - Rebuild HenSurf with your changes:
     ```bash
     ./scripts/build.sh
     ```
   - Perform manual testing as described in the [Testing](#testing) section.
   - Run relevant automated tests if applicable.

5. **Submit Pull Request (PR)**
   - Push your feature branch to your fork on GitHub: `git push origin feature/your-feature-name`
   - Go to the HenSurf GitHub repository and you should see a prompt to create a new Pull Request from your pushed branch.
   - **Write a Clear PR Description:**
     - **Title:** Similar to your commit message subject, make it clear and concise.
     - **Link to Issues:** If your PR addresses an existing GitHub issue, include "Fixes #issue-number" or "Closes #issue-number" in the description. This will automatically link the PR to the issue and close the issue when the PR is merged.
     - **Summary of Changes:** Briefly explain what the PR does. What problem does it solve or what feature does it add?
     - **How to Test:** Provide clear, step-by-step instructions on how a reviewer can test your changes. This is very important!
     - **Screenshots/GIFs (if applicable):** For UI changes, include screenshots or GIFs to visually demonstrate the changes.
     - **Self-Review Checklist:** Mention if you've followed the code style, added tests, updated docs, etc. (refer to the [Code Review Checklist](#code-review-checklist)).

### Issue Reporting

#### Bug Reports
- **Title**: Clear, specific description
- **Steps**: Detailed reproduction steps
- **Environment**: OS version, HenSurf version
- **Logs**: Relevant error messages

#### Feature Requests
- **Use Case**: Why is this needed?
- **Privacy Impact**: How does this affect privacy?
- **Implementation**: Suggested approach

### Security

#### Reporting Security Issues
- **Private Disclosure**: Email security issues privately
- **No Public Discussion**: Until fix is available
- **Responsible Disclosure**: Follow standard practices

#### Security Review
- All changes reviewed for security implications
- Privacy impact assessment required
- No new tracking or data collection

## Resources

### Documentation
- [Chromium Development Docs](https://www.chromium.org/developers/)
- [Chromium Build Instructions (General)](https://www.chromium.org/developers/how-tos/get-the-code/)
- [GN Build System](https://gn.googlesource.com/gn/+/main/docs/)
- [Ninja Build](https://ninja-build.org/manual.html)

### Tools
- `depot_tools`: Managed by `scripts/install-deps.sh`.
- `gclient`: Part of `depot_tools`, used for managing Chromium checkout.
- `gn`: Build configuration generator.
- `autoninja`: Wrapper for `ninja` build system.
- [Chromium Code Search](https://source.chromium.org/chromium)

### Community
- HenSurf GitHub Issues: For bug reports and feature tracking specific to HenSurf.
- HenSurf GitHub Discussions: For questions, ideas, and general discussion.

## Branding and Logo Setup

The branding assets (icons, `BRANDING` file) are located in the `src/hensurf/branding/` directory.
The `scripts/setup-logo.sh` script is responsible for:
- Copying all PNG icons to their correct locations within `src/chromium/chrome/app/theme/`.
- Generating `chrome.ico` for Windows (if ImageMagick `convert` is available).
- Generating `app.icns` for macOS (if `iconutil` is available on a macOS host).
- Creating/updating `src/chromium/chrome/app/chrome_exe.ver` with HenSurf branding details for Windows executables.
# Note: The HenSurf-specific theme directory (src/chromium/chrome/app/theme/hensurf), including its BRANDING file,
# has been moved to src/hensurf/branding/theme/hensurf/.
# scripts/setup-logo.sh no longer copies the main src/hensurf/branding/BRANDING file to the old theme location.
# Build system (GN) files are expected to reference assets from src/hensurf/branding/theme/hensurf/ directly.

This script is called automatically by `scripts/apply-patches.sh` after other patches are applied.
If you only need to update logo/icon files after making changes in the `src/hensurf/branding/icons/` directory, you can run `scripts/setup-logo.sh` directly (ensure you are in the project root, or that the script can correctly find `PROJECT_ROOT` and `CHROMIUM_SRC`).

## Fast Developer Builds

The `scripts/interactive_build.sh` script is the recommended way to start builds. For faster iteration during development, you can also use `scripts/build.sh` directly with the `--dev-fast` flag:

```bash
./scripts/build.sh --dev-fast
# This will build for your native OS and architecture.
# You can combine it with HENSURF_TARGET_OS, HENSURF_TARGET_CPU, HENSURF_OUTPUT_DIR
# environment variables for specific targets if needed.
```

This flag typically sets GN arguments like:
- `is_component_build = true`: Builds Chromium modules as separate shared libraries. This dramatically speeds up link times for incremental builds as only modified components need to be relinked.
- `treat_warnings_as_errors = false`: Allows the build to continue even if new warnings are encountered.

**Important Considerations for Dev Fast Builds:**
- Builds created with `--dev-fast` are **not suitable for distribution or release**. They are intended for local development and testing only.
- Component builds may have a slight runtime performance overhead compared to monolithic builds.
- While `treat_warnings_as_errors = false` can speed up iteration, it's crucial to address warnings before finalizing changes or submitting them for CI/release builds.
