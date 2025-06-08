# HenSurf Browser Architecture

## Table of Contents

- [Overview](#overview)
- [Key Modifications](#key-modifications)
  - [1. AI Feature Removal](#1-ai-feature-removal)
  - [2. Google Services Removal](#2-google-services-removal)
  - [3. Privacy Enhancements](#3-privacy-enhancements)
  - [4. Bloatware Removal](#4-bloatware-removal)
- [Build System](#build-system)
  - [Configuration](#configuration)
  - [Patch System](#patch-system)
  - [Build Process](#build-process)
- [Security Considerations](#security-considerations)
  - [Removed Attack Vectors](#removed-attack-vectors)
  - [Enhanced Security](#enhanced-security)
- [Performance Benefits](#performance-benefits)
  - [Reduced Resource Usage](#reduced-resource-usage)
  - [Network Efficiency](#network-efficiency)
- [Maintenance Strategy](#maintenance-strategy)
  - [Upstream Tracking](#upstream-tracking)
  - [Testing](#testing)
- [Future Enhancements](#future-enhancements)
  - [Planned Features](#planned-features)
  - [Research Areas](#research-areas)
- [Comparison with Other Browsers](#comparison-with-other-browsers)
- [Contributing](#contributing)

HenSurf is a privacy-focused, lightweight browser based on Chromium with AI features and bloatware removed.

## Overview

HenSurf takes the open-source Chromium browser and applies targeted modifications to:
- Remove AI-powered features
- Disable Google services integration
- Enhance privacy by default
- Eliminate promotional content and bloatware
- Provide a clean, fast browsing experience

## Key Modifications

### 1. AI Feature Removal

**Removed Components:**
- Autofill Assistant (AI-powered form filling)
- Smart suggestions and predictions
- Machine learning-based features
- Google Now integration
- Voice search and hotwording
- Supervised user features

**Implementation:**
- Specific settings in the build configuration (known as 'build flags') disable these AI components when HenSurf is compiled.
- Custom modifications (patches) to the source code remove AI-related user interface elements.
- Libraries and code related to machine learning are excluded from the final browser.

### 2. Google Services Removal

**Disabled Services:**
- Google API integration
- Account sync and signin
- Cloud policy management
- Safe browsing (Google-based)
- Spell checking (Google-based)
- Crash reporting to Google
- Usage statistics and metrics

**Implementation:**
- API keys removed/disabled
- Network requests to Google services blocked
- Authentication flows disabled
- Local alternatives implemented where possible

### 3. Privacy Enhancements

**Default Settings:**
- DuckDuckGo as default search engine
- Enhanced tracking protection enabled
- Third-party cookies blocked
- DNS-over-HTTPS with privacy-focused providers
- No telemetry or usage data collection

**Technical Implementation:**
- Modified prepopulated search engines
- Updated default privacy preferences
- Removed tracking and analytics code

### 4. Bloatware Removal

**Removed Features:**
- Promotional tabs and content
- Welcome/onboarding flows
- App suggestions and recommendations
- Chrome Web Store promotions
- Google services advertisements

**Implementation:**
- UI components removed via patches
- Promotional content files deleted
- Marketing-related code disabled

## Build System

The build system is responsible for compiling the Chromium source code and applying HenSurf's specific modifications to create the final browser.

### Configuration

HenSurf tailors the Chromium build process using a special configuration file located at `src/hensurf/config/hensurf.gn`. This file acts like a detailed set of instructions for Chromium's build system (called GN, which stands for "Generate Ninja" build files). These instructions tell the build system to:
- Turn off unwanted functionalities using 'build flags'. Build flags are essentially on/off switches that control which features are included or excluded during compilation.
- Adjust settings to optimize for better privacy and faster performance.
- Exclude components and integrations that are specific to Google's services.
- Include only the core features necessary for a clean and lightweight browsing experience.

### Patch System

HenSurf makes direct changes to Chromium's original source code using a 'patch system'. Patches are files (stored in the `src/hensurf/patches/` directory) that describe specific additions, removals, or modifications to the Chromium code. These `.patch` files are applied using standard tools like `git apply`. They are responsible for:
- Modifying the browser's underlying C++ and other code to alter its behavior (e.g., removing AI features, disabling Google services).
- Removing visual elements from the user interface (UI) related to disabled features.
- Changing default browser settings (e.g., search engine).

Branding assets (icons, version information) are handled by a combination of patches (for integrating code changes like user agent) and dedicated scripts (`scripts/setup-logo.sh`) that place physical files into the source tree.

### Build Process

The build process is orchestrated by a series of shell scripts:

1.  **Dependency Installation (`scripts/install-deps.sh`)**:
    *   Checks for and helps install essential build tools (Python, Git, Ninja, C++ compiler toolchain for the host OS).
    *   Downloads and sets up `depot_tools`, Chromium's bootstrap toolset.
    *   Verifies system requirements like disk space and RAM.

2.  **Source Fetch (`scripts/fetch-chromium.sh`)**:
    *   Uses `depot_tools` (specifically `gclient` and `fetch`) to download the Chromium source code.
    *   Runs initial `gclient runhooks` to download toolchains (like Clang) and other binary dependencies.
    *   Offers an optional enhanced sync for full commit history.

3.  **Customization Application (`scripts/apply-patches.sh`)**:
    *   Applies HenSurf's custom `.patch` files to the Chromium source code.
    *   Creates or modifies C++ files for specific HenSurf behavior (e.g., `hensurf_version_info.cc` for user agent, `google_api_keys.cc` to disable keys).
    *   Updates the `chrome/VERSION` file with HenSurf branding.
    *   Calls `scripts/setup-logo.sh` to place all static branding assets (icons, `BRANDING` file, `chrome_exe.ver`).

4.  **Compilation (`scripts/build.sh` or `scripts/interactive_build.sh`)**:
    *   `interactive_build.sh` provides a user-friendly menu to select common build targets and then invokes `build.sh`.
    *   `build.sh` is the core compilation script:
        *   Sets up environment variables for target OS, CPU, and output directory (can be overridden by user).
        *   Performs host system checks (RAM, disk space).
        *   Constructs GN arguments based on feature flags and target configuration.
        *   Runs `gn gen` to generate Ninja build files.
        *   Runs `autoninja` to compile the browser and additional components (like `chromedriver`, `mini_installer`).
        *   Handles macOS application bundle creation (`HenSurf.app`) if applicable.

5.  **Testing (Optional, via `scripts/run_all_tests.py` or individual test scripts)**:
    *   `run_all_tests.py` can orchestrate custom tests (`test-hensurf.sh`/`.ps1`) and standard Chromium tests (e.g., `browser_tests`, `unit_tests`).

This structured process ensures that all modifications and branding are correctly applied before the final browser is compiled.

## Security Considerations

### Removed Attack Vectors
- No Google API communication
- No cloud sync vulnerabilities
- Reduced network surface area
- No AI model exploitation risks

### Enhanced Security
- Local-only features where possible
- Minimal external dependencies
- Privacy-focused defaults
- Regular security updates from Chromium upstream

## Performance Benefits

### Reduced Resource Usage
- No AI processing overhead
- Fewer background services
- Smaller memory footprint
- Faster startup times

### Network Efficiency
- No telemetry uploads
- Reduced external requests
- Local search suggestions
- Minimal tracking protection overhead

## Maintenance Strategy

### Upstream Tracking
- Regular Chromium security updates
- Selective feature adoption
- Patch compatibility maintenance

### Testing
- Automated build verification
- Privacy feature testing
- Performance benchmarking
- Security audit procedures

## Future Enhancements

### Planned Features
- Built-in ad blocker
- Enhanced privacy dashboard
- Local bookmark sync
- Custom extension store

### Research Areas
- Alternative search integration
- Decentralized sync solutions
- Advanced privacy features
- Performance optimizations

## Comparison with Other Browsers

| Feature | HenSurf | Chrome | Brave | Firefox |
|---------|---------|--------|-------|----------|
| AI Features | ❌ | ✅ | ❌ | ❌ |
| Google Services | ❌ | ✅ | ❌ | ❌ |
| Built-in Ads | ❌ | ❌ | ✅ | ❌ |
| Telemetry | ❌ | ✅ | ⚠️ | ⚠️ |
| Privacy Default | ✅ | ❌ | ✅ | ✅ |
| Performance | ✅ | ✅ | ✅ | ⚠️ |
| Open Source | ✅ | ⚠️ | ✅ | ✅ |

## Contributing

See the main [Project README](../README.md) for contribution guidelines and development setup instructions.
