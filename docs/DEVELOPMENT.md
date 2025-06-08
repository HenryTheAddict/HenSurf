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
- **Xcode Command Line Tools**
- **16GB+ RAM** (32GB recommended)
- **100GB+ free disk space**
- **Fast internet connection** (for initial source download)

### Quick Setup

This guide assumes you have already cloned the HenSurf repository and are in its root directory.

```bash
# Install dependencies
./scripts/install-deps.sh

# Fetch Chromium source (takes 30-60 minutes)
./scripts/fetch-chromium.sh

# Apply HenSurf customizations
./scripts/apply-patches.sh

# Build HenSurf (takes 2-8 hours)
./scripts/build.sh
```

## Development Workflow

### Making Changes

1. **Modify Source Code**
   ```bash
   cd chromium/src
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
   - Navigate to the Chromium source directory: `cd chromium/src`.
   - Use `git status` to see which files you've modified.
   - Use `git add <file_path>` for each file you want to include in the patch. This stages the changes for commit (though we are generating a diff, staging helps `git diff --staged`).

**2. Generate the Patch File:**
   - Once you have staged the changes for your specific feature or fix, generate the patch file using `git diff`.
   - It's crucial to be in the `chromium/src` directory.
   - The output of `git diff --staged` is what you need for your patch file.
   ```bash
   cd chromium/src
   # Ensure you've staged only the files relevant to this specific patch
   # git add path/to/modified/file1.cc
   # git add path/to/another/modified/file2.h

   # Generate the patch relative to the HenSurf project root
   git diff --staged > ../../patches/my-new-feature-or-fix.patch
   ```
   - **Naming Convention:** Use a descriptive name for your patch file, like `remove-profile-import-dialog.patch` or `fix-crash-on-settings-page.patch`.

**3. Add Patch to Apply Script:**
   - For your patch to be applied during the HenSurf build process, you must add it to the `./scripts/apply-patches.sh` script.
   - Open `./scripts/apply-patches.sh` in a text editor.
   - Add a line that applies your patch. Patches are typically applied with `patch -p1`. The `-p1` option tells the `patch` command to strip the first component from the file paths in the patch file (e.g., `a/chrome/browser/ui/some_file.cc` becomes `chrome/browser/ui/some_file.cc`), which is usually correct for patches generated from `chromium/src`.
   ```bash
   # Example line to add in apply-patches.sh
   echo "Applying patch for my new feature or fix"
   patch -p1 < ../../patches/my-new-feature-or-fix.patch
   ```
   - Place your patch in a logical order within `apply-patches.sh`, perhaps grouped with similar patches.

**4. Test Patch Application:**
   - After adding your patch to the script, you can test if it applies cleanly by running:
   ```bash
   # From the HenSurf project root
   ./scripts/apply-patches.sh
   ```
   - If there are issues, you may need to regenerate your patch or adjust its position in the `apply-patches.sh` script.

**Important Considerations for Patches:**
   - **Atomicity:** Each patch should be as small as possible while addressing a single concern. This makes it easier to review, debug, and manage if Chromium upstream code changes.
   - **Clarity:** Ensure your code changes within the patch are clean and follow the Chromium style guide.
   - **Maintenance:** Patches can break when the underlying Chromium code changes. Be prepared to update your patches when pulling in new versions of Chromium. This is known as "rebasing" or "porting" patches.

### Build Configurations

#### Debug Build
```bash
# Create debug configuration
mkdir -p chromium/src/out/Debug
echo 'is_debug = true' > chromium/src/out/Debug/args.gn
echo 'symbol_level = 2' >> chromium/src/out/Debug/args.gn

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
rm -rf chromium/src/out/HenSurf
gn gen chromium/src/out/HenSurf

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
# Run browser tests
autoninja -C out/HenSurf browser_tests
./out/HenSurf/browser_tests --gtest_filter=*Privacy*
```

#### Performance Tests
```bash
# Build performance test tools
autoninja -C out/HenSurf performance_test_suite
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
echo 'cc_wrapper = "ccache"' >> out/HenSurf/args.gn
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
   # Edit version in branding/BRANDING
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
rm -rf chromium/src/out/HenSurf
./scripts/apply-patches.sh
./scripts/build.sh

# Create installer
autoninja -C chromium/src/out/HenSurf chrome/installer/mac
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
- [Chromium Development](https://chromium.googlesource.com/chromium/src/+/main/docs/)
- [GN Build System](https://gn.googlesource.com/gn/+/main/docs/)
- [Ninja Build](https://ninja-build.org/manual.html)

### Tools
- [depot_tools](https://chromium.googlesource.com/chromium/tools/depot_tools)
- [GN Reference](https://gn.googlesource.com/gn/+/main/docs/reference.md)
- [Chromium Code Search](https://source.chromium.org/)

### Community
- GitHub Issues for bug reports
- Discussions for feature requests
- Wiki for additional documentation