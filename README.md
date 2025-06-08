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
*   **Disk Space:** At least **150GB** of free disk space on an NTFS-formatted drive. It is not 1995 dont use FAT32.
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
    ./scripts/interactive_build.sh
    ```
    This script provides an interactive menu to choose your build target (e.g., Native OS, Linux x64, Windows x64, macOS). This is the **recommended** way to build HenSurf.
    The build process is very lengthy (can take multiple hours, or even days depending on your CPU and RAM. Please have more than 16GB!).

**Output Directory Structure:**

Builds for different targets will now reside in separate, target-specific directories under `src/chromium/out/`. This allows you to maintain multiple builds for different operating systems or architectures simultaneously.

Examples of output directory names:
*   `HenSurf-linux-x64`
*   `HenSurf-mac-arm64`
*   `HenSurf-mac-x64`
*   `HenSurf-win-x64`

If you run `scripts/build.sh` directly without `HENSURF_` environment variables, it will build for your native OS and architecture in a directory like `HenSurf-<your_os>-<your_arch>`.

**Running HenSurf:**

After a successful build, the main executable and any installers will be located within the target-specific output directory. For example:

*   **Windows:**
    *   Executable: `src/chromium/out/HenSurf-win-x64/chrome.exe`
    *   Installer (if built): `src/chromium/out/HenSurf-win-x64/mini_installer.exe` or `setup.exe`
*   **macOS:**
    *   App Bundle: `src/chromium/out/HenSurf-mac-arm64/HenSurf.app` (for ARM64) or `src/chromium/out/HenSurf-mac-x64/HenSurf.app` (for Intel x64)
    *   Installer (if built): `src/chromium/out/HenSurf-mac-<arch>/*.dmg`
*   **Linux:**
    *   Executable: `src/chromium/out/HenSurf-linux-x64/chrome`

Always replace `<os>` and `<arch>` with the specific target you built for.

**Important Notes for Windows Builds:**

*   **Git Bash:** All `.sh` scripts **must** be run from a Git Bash terminal. Do not use CMD or PowerShell for these scripts.
*   **Resource Intensive:** Building Chromium is extremely demanding on CPU, RAM, and disk I/O.
*   **Time Consuming:** Expect the entire process (fetch + build) to take several hours, even on powerful hardware.
*   **`depot_tools` PATH:** Ensure `depot_tools` is correctly added to your Windows PATH environment variable (as instructed by `install-deps.sh`) for subsequent terminal sessions.
*   **Long File Paths:** Ensure your repository is cloned to a path with a short overall length (e.g., `C:\dev\hensurf`) to avoid issues with Windows' maximum path length limits during the build.

## Quick Start

The following steps are a general guide. Windows users, please refer to the "Building on Windows" section above for specific Windows prerequisites and detailed environment setup. For all users, the new interactive build script is the recommended way to compile HenSurf.

1.  **Install Dependencies:**
    ```bash
    ./scripts/install-deps.sh
    ```
    This script will guide you through initial setup, including `depot_tools`. Pay attention to its output, especially for Windows setup.

2.  **Download Chromium Source Code:**
    ```bash
    ./scripts/fetch-chromium.sh
    ```
    This downloads the entire Chromium source. It's a large download and can take a significant amount of time.

3.  **Apply HenSurf Customizations:**
    ```bash
    ./scripts/apply-patches.sh
    ```
    This script applies HenSurf's modifications to the Chromium source code.

4.  **Build HenSurf (Recommended Method):**
    ```bash
    ./scripts/interactive_build.sh
    ```
    This script presents a menu to choose your build target:
    *   **1. Native OS:** Automatically detects your current operating system and CPU architecture (e.g., `arm64` or `x64` on macOS).
    *   **2. Linux (x64):** Cross-compiles for Linux x64.
    *   **3. Windows (x64):** Cross-compiles for Windows x64.
    *   **4. macOS (Intel x64):** Cross-compiles for macOS on Intel x64.
    *   **5. macOS (ARM64):** Cross-compiles for macOS on ARM64 (Apple Silicon).
    *   **6. macOS (Both Intel x64 and ARM64):** Builds for both macOS architectures. It will build for your native Mac architecture first, then the other.
    *   **7. Exit:** Cancels the build.

    The build process is very lengthy and resource-intensive. Output will be in a target-specific directory like `src/chromium/out/HenSurf-<os>-<arch>`.

5.  **Alternative Build Method (`build.sh`):**
    You can still invoke `scripts/build.sh` directly. If run without specific `HENSURF_TARGET_OS`, `HENSURF_TARGET_CPU`, or `HENSURF_OUTPUT_DIR` environment variables, it will default to building for your native OS and architecture, placing artifacts in a directory like `src/chromium/out/HenSurf-<native_os>-<native_arch>`. For more complex scenarios or CI, `build.sh` can be used with these environment variables to precisely control the build target and output location.

## Project Structure

```
HenSurf/
├── README.md              # This file, hello btw!
├── LICENSE                # BSD 3-Clause License
├── Hensurf.png            # HenSurf's logo!
├── scripts/               # Build and setup scripts
│   ├── install-deps.sh    # Install build dependencies
│   ├── fetch-chromium.sh  # Download Chromium source
    ├── apply-patches.sh   # Apply HenSurf customizations (patches, code generation, calls setup-logo.sh)
    ├── setup-logo.sh      # Sets up all logo icons and branding files
    ├── build.sh           # Core build script (can be parameterized)
    ├── interactive_build.sh # Recommended interactive build script
│   └── test-hensurf.sh    # Test the built browser (Bash)
│   └── test-hensurf.ps1   # Test the built browser (PowerShell for Windows)
│   └── run_all_tests.py   # Python script to orchestrate tests
├── src/hensurf/patches/   # Source code modifications
│   ├── remove-ai-features.patch
# Note: remove-bloatware.patch is often a conceptual goal achieved via multiple patches or GN flags
# │   ├── remove-bloatware.patch
│   └── integrate-logo.patch
├── src/hensurf/branding/  # HenSurf branding assets
│   ├── BRANDING           # Main branding configuration file (used by setup-logo.sh)
│   └── icons/             # Generated browser icons
│       ├── icon_16.png    # 16x16 favicon
│       ├── icon_32.png    # 32x32 small icon
│       ├── icon_48.png    # 48x48 medium icon
│       ├── icon_64.png    # 64x64 large icon
│       ├── icon_128.png   # 128x128 app icon
│       ├── icon_256.png   # 256x256 high-res icon
│       ├── icon_512.png   # 512x512 retina icon
│       └── icon_manifest.json # Icon metadata
├── src/hensurf/config/    # Build configuration
│   ├── hensurf.gn         # GN build arguments
│   └── features.json      # Feature configuration
└── docs/                  # Documentation
    ├── ARCHITECTURE.md    # Technical architecture
    ├── DEVELOPMENT.md     # Development guide
    ├── PRIVACY.md         # Privacy policy
    └── INDEX.md           # Index for docs (if used)
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
*   **Clean Build Directory**: Sometimes, previous build artifacts can cause issues. If you suspect a corrupted build state, you can remove the specific target output directory before rebuilding. For example, if your Linux x64 build failed:
    ```bash
    # Be careful with rm -rf!
    rm -rf src/chromium/out/HenSurf-linux-x64
    ```
    Then, re-run `scripts/interactive_build.sh` or `scripts/build.sh`.
*   **Check Logs**: Build and runtime logs can provide valuable information about what went wrong. Look for error messages in the console output. HenSurf build logs are now located in the target-specific output directory, e.g.:
    `src/chromium/out/HenSurf-<os>-<arch>/build.log`
*   **Disk Space**: Ensure you have sufficient free disk space (at least 150GB recommended, more if building for multiple targets) as Chromium's source and build files are very large.
*   **Memory Usage**: Building Chromium is memory-intensive. If the build fails with errors related to memory, ensure you have enough RAM (16GB+ recommended, 32GB+ for a smoother experience) and close other memory-heavy applications.
*   **Consult Chromium Documentation**: For issues related to the underlying Chromium build system, the official [Chromium build documentation](https://www.chromium.org/developers/how-tos/get-the-code/) can be a helpful resource.

## Contributing

Please see `CONTRIBUTING.md` for details on how to contribute to the HenSurf Browser project.
We welcome bug reports, feature requests, and pull requests!

## License

HenSurf is based on Chromium and follows the same BSD-style license.
See the LICENSE file for details.

## Disclaimer

This project is not affiliated with Google or the Chromium project.
Chromium is a trademark of Google Inc.
