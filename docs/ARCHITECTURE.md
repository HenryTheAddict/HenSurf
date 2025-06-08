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

HenSurf tailors the Chromium build process using a special configuration file located at `config/hensurf.gn`. This file acts like a detailed set of instructions for Chromium's build system (called GN, which stands for "Generate Ninja" build files). These instructions tell the build system to:
- Turn off unwanted functionalities using 'build flags'. Build flags are essentially on/off switches that control which features are included or excluded during compilation.
- Adjust settings to optimize for better privacy and faster performance.
- Exclude components and integrations that are specific to Google's services.
- Include only the core features necessary for a clean and lightweight browsing experience.

### Patch System

HenSurf makes direct changes to Chromium's original source code using a 'patch system'. Patches are files (stored in the `patches/` directory) that describe specific additions, removals, or modifications to the Chromium code. Think of them as precise, targeted edits. These patches are responsible for:
- Modifying the browser's underlying C++ and other code to alter its behavior.
- Removing visual elements from the user interface (UI), such as buttons or menus related to disabled features.
- Changing default browser settings, like setting DuckDuckGo as the default search engine or enabling stricter privacy options from the start.
- Applying HenSurf's unique branding, including its name, logos, and icons throughout the browser.

### Build Process

1. **Dependency Installation** (`install-deps.sh`)
   - Installs required build tools
   - Sets up depot_tools
   - Verifies system requirements

2. **Source Fetch** (`./scripts/fetch-chromium.sh`)
   - Downloads the Chromium source code from Google's repositories.
   - Applies initial Chromium-specific setup.
   - Prepares the overall build environment.

3. **Patch Application** (`./scripts/apply-patches.sh`)
   - Systematically applies HenSurf's custom patches (from the `patches/` directory) to the Chromium source code.
   - This step integrates HenSurf's specific branding, default configurations, and feature removals.

4. **Build Execution** (`./scripts/build.sh`)
   - Compiles the modified Chromium source code to create the HenSurf browser application.
   - Packages the compiled browser into an application bundle (e.g., `.app` for macOS).
   - May also generate an installer if applicable for the operating system.

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
