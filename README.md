# HenSurf Browser

A privacy-focused, lightweight Chromium-based browser without AI features and bloatware.

## Overview

HenSurf is a custom build of Chromium that removes:
- AI-powered features and suggestions
- Google services integration
- Telemetry and data collection
- Promotional content and bloatware
- Unnecessary extensions and services

## Features

- ✅ Clean, minimal interface
- ✅ Enhanced privacy by default
- ✅ No AI suggestions or machine learning
- ✅ No Google services integration
- ✅ Minimal telemetry
- ✅ Fast and lightweight
- ✅ Open source

## Build Requirements

- macOS 10.15 or later
- Xcode Command Line Tools
- Python 3.8+
- Git
- At least 100GB free disk space
- 16GB+ RAM recommended

## Quick Start

1. Install dependencies:
   ```bash
   ./scripts/install-deps.sh
   ```

2. Download Chromium source:
   ```bash
   ./scripts/fetch-chromium.sh
   ```

3. Apply HenSurf patches:
   ```bash
   ./scripts/apply-patches.sh
   ```

4. Build HenSurf:
   ```bash
   ./scripts/build.sh
   ```

## Project Structure

```
HenSurf/
├── README.md              # This file
├── LICENSE                # BSD 3-Clause License
├── Hensurf.png            # HenSurf logo (source)
├── scripts/               # Build and setup scripts
│   ├── install-deps.sh    # Install build dependencies
│   ├── fetch-chromium.sh  # Download Chromium source
│   ├── apply-patches.sh   # Apply HenSurf customizations
│   ├── setup-logo.sh      # Integrate HenSurf logo
│   ├── build.sh           # Build the browser
│   └── test-hensurf.sh    # Test the built browser
├── patches/               # Source code modifications
│   ├── remove-ai-features.patch
│   ├── remove-bloatware.patch
│   └── integrate-logo.patch
├── branding/              # HenSurf branding files
│   ├── BRANDING           # Brand configuration
│   └── icons/             # Generated browser icons
│       ├── icon_16.png    # 16x16 favicon
│       ├── icon_32.png    # 32x32 small icon
│       ├── icon_48.png    # 48x48 medium icon
│       ├── icon_64.png    # 64x64 large icon
│       ├── icon_128.png   # 128x128 app icon
│       ├── icon_256.png   # 256x256 high-res icon
│       ├── icon_512.png   # 512x512 retina icon
│       └── icon_manifest.json # Icon metadata
├── config/                # Build configuration
│   ├── hensurf.gn         # GN build arguments
│   └── features.json      # Feature configuration
└── docs/                  # Documentation
    ├── ARCHITECTURE.md    # Technical architecture
    ├── DEVELOPMENT.md     # Development guide
    └── PRIVACY.md         # Privacy policy
```

## Configuration

HenSurf uses custom build configurations to remove unwanted features:

- **No AI Features**: Disables machine learning, smart suggestions, and AI-powered features
- **No Google Services**: Removes Google account integration, sync, and services
- **Privacy First**: Enhanced privacy settings enabled by default
- **Minimal Telemetry**: Only essential crash reporting (can be disabled)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the build
5. Submit a pull request

## License

HenSurf is based on Chromium and follows the same BSD-style license.
See LICENSE file for details.

## Disclaimer

This project is not affiliated with Google or the Chromium project.
Chromium is a trademark of Google Inc.