# HenSurf Development Guide

This guide covers development workflows, debugging, and contribution guidelines for HenSurf.

## Development Environment Setup

### Prerequisites

- **macOS 10.15+** (Catalina or later)
- **Xcode Command Line Tools**
- **16GB+ RAM** (32GB recommended)
- **100GB+ free disk space**
- **Fast internet connection** (for initial source download)

### Quick Setup

```bash
# Clone HenSurf repository
git clone <repository-url> HenSurf
cd HenSurf

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

When making changes to Chromium source:

```bash
# Create a patch for your changes
cd chromium/src
git diff > ../../patches/my-feature.patch

# Add patch to apply-patches.sh
echo 'patch -p1 < ../../patches/my-feature.patch' >> ../../scripts/apply-patches.sh
```

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

3. **Make Changes**
   - Follow code style guidelines
   - Add tests for new features
   - Update documentation

4. **Test Changes**
   ```bash
   ./scripts/build.sh
   # Manual testing
   ```

5. **Submit Pull Request**
   - Clear description of changes
   - Reference any related issues
   - Include testing instructions

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