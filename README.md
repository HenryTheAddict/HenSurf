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

## Build Requirements (macOS / Linux)

- macOS 10.15+ or a modern Linux distribution (e.g., Ubuntu, Fedora, Arch)
- Xcode Command Line Tools (for macOS) or `build-essential` package (for Linux, provides `gcc`, `g++`, `make`)
- Python 3.8+ (must be accessible as `python3` or `python`)
- Git
- At least 150GB free disk space (Chromium source code and build artifacts are very large).
- 16GB+ RAM recommended (32GB+ for faster builds).

For Windows, please see the "Building on Windows" section below.

## Building on Windows

Building Chromium (and thus HenSurf) on Windows has specific prerequisites and requires using Git Bash for the provided scripts.

**Prerequisites:**

*   **Git for Windows:** Essential for cloning the repository and running the build scripts.
    *   **Download:** [https://git-scm.com/download/win](https://git-scm.com/download/win)
    *   **Important:** You **must** use **Git Bash** (which comes with Git for Windows) to run all `.sh` scripts.
*   **Python:** Version 3.8+ is required by Chromium's build tools.
    *   **Download:** [https://www.python.org/downloads/windows/](https://www.python.org/downloads/windows/)
    *   Ensure you add Python to your system PATH during installation.
*   **Ninja Build Tool:** A small build system used by Chromium.
    *   **Download:** [https://github.com/ninja-build/ninja/releases](https://github.com/ninja-build/ninja/releases)
    *   Download `ninja.exe` from the latest Windows release.
    *   Create a directory (e.g., `C:\Ninja`) and place `ninja.exe` there.
    *   Add this directory to your system PATH.
*   **Visual Studio C++ Build Tools:** Crucial for compiling C++ code on Windows.
    *   **Download:** [https://visualstudio.microsoft.com/downloads/](https://visualstudio.microsoft.com/downloads/) (Community edition is free and sufficient).
    *   **Required Workload:** During installation, you **must** select the "Desktop development with C++" workload.
    *   HenSurf typically builds with VS 2019 (e.g., v16.11.14+) or VS 2022. `depot_tools` (installed by `install-deps.sh`) may try to manage this if specific environment variables are set (see `install-deps.sh` output).
*   **(Optional) Chocolatey for Prerequisite Installation:**
    *   If you use the [Chocolatey](https://chocolatey.org/) package manager, you can install most prerequisites with a command like (run in an **Administrator** PowerShell or CMD prompt):
        ```powershell
        choco install python git ninja visualstudio2022buildtools --package-parameters "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended"
        # Note: Verify the exact package names and parameters if issues arise.
        ```
    *   Close and reopen Git Bash after installing tools to ensure PATH changes take effect.
*   **Disk Space:** At least **150GB** of free disk space on an NTFS-formatted drive.
*   **RAM:** **16GB+** highly recommended (32GB+ for a significantly better experience).

**Build Steps:**

1.  **Open Git Bash:** All subsequent commands should be run in a Git Bash terminal.
2.  **Clone HenSurf Repository:**
    ```bash
    git clone https://github.com/HenryTheAddict/HenSurf
    cd hensurf
    ```
3.  **Install Dependencies & depot_tools:**
    ```bash
    ./scripts/install-deps.sh
    ```
    This script will check for Python, Git, and Ninja. It will also download `depot_tools` (Chromium's bootstrap toolset). Pay close attention to its output, especially regarding Visual Studio and adding `depot_tools` to your PATH permanently.
4.  **Fetch Chromium Source Code:**
    ```bash
    ./scripts/fetch-chromium.sh
    ```
    This is a lengthy process that downloads the entire Chromium source code. It can take 30 minutes to several hours depending on your internet connection and consume ~100GB of disk space.
5.  **Apply HenSurf Customizations:**
    ```bash
    ./scripts/apply-patches.sh
    ```
    This script applies HenSurf's modifications to the Chromium source.
6.  **Build HenSurf:**
    ```bash
    ./scripts/build.sh
    ```
    This compiles the browser. This is also a very lengthy process (can take multiple hours depending on your CPU and RAM).

**Running HenSurf on Windows:**

*   After a successful build, the main executable will be located at:
    `chromium/src/out/HenSurf/chrome.exe`
*   An installer might also be created (the name can vary):
    `chromium/src/out/HenSurf/mini_installer.exe` or `chromium/src/out/HenSurf/setup.exe`

**Important Notes for Windows Builds:**

*   **Git Bash:** All `.sh` scripts **must** be run from a Git Bash terminal. Do not use CMD or PowerShell for these scripts.
*   **Resource Intensive:** Building Chromium is extremely demanding on CPU, RAM, and disk I/O.
*   **Time Consuming:** Expect the entire process (fetch + build) to take several hours, even on powerful hardware.
*   **`depot_tools` PATH:** Ensure `depot_tools` is correctly added to your Windows PATH environment variable (as instructed by `install-deps.sh`) for subsequent terminal sessions.
*   **Long File Paths:** Ensure your repository is cloned to a path with a short overall length (e.g., `C:\dev\hensurf`) to avoid issues with Windows' maximum path length limits during the build.

## Quick Start

The following steps are a general guide. Windows users, please refer to the "Building on Windows" section above for specific prerequisites and detailed environment setup.

1. Install dependencies:
   ```bash
   ./scripts/install-deps.sh
   ```
   This script will guide you through initial setup, including `depot_tools`.

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

## Troubleshooting

If you encounter issues while building or running HenSurf, here are some common troubleshooting steps:

*   **Check Dependencies**: Ensure all build requirements (macOS/Linux or Windows specific) are installed correctly. You can try re-running the dependency installation script:
    ```bash
    ./scripts/install-deps.sh
    ```
*   **Clean Build Directory**: Sometimes, previous build artifacts can cause issues. Clean your build directory (typically `chromium/src/out/HenSurf`) and try again.
*   **Check Logs**: Build and runtime logs can provide valuable information about what went wrong. Look for error messages in the console output. HenSurf build logs are typically found in `chromium/src/out/HenSurf/build.log`.
*   **Disk Space**: Ensure you have sufficient free disk space (at least 150GB recommended) as Chromium's source and build files are very large.
*   **Memory Usage**: Building Chromium is memory-intensive. If the build fails with errors related to memory, ensure you have enough RAM (16GB+ recommended) and close other memory-heavy applications.
*   **Consult Chromium Documentation**: For issues related to the underlying Chromium build system, the official [Chromium build documentation](https://www.chromium.org/developers/how-tos/get-the-code/) can be a helpful resource.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the build
5. Submit a pull request

## License

HenSurf is based on Chromium and follows the same BSD-style license.
See the LICENSE file for details.

## Disclaimer

This project is not affiliated with Google or the Chromium project.
Chromium is a trademark of Google Inc.
