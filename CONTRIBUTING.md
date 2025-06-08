# Contributing to HenSurf Browser

First off, thank you for considering contributing to HenSurf Browser! We welcome your help to make this browser even better. Whether it's reporting a bug, suggesting a feature, or writing code, your contributions are valuable.

## How to Contribute

There are several ways you can contribute to the project:

### Bug Reports
If you find a bug, please help us by reporting it!
*   **Action**: Submit a bug report via [GitHub Issues](https://github.com/HenryTheAddict/HenSurf/issues).
*   **Details**: Please include:
    *   Steps to reproduce the bug.
    *   What you expected to happen.
    *   What actually happened.
    *   Your operating system and HenSurf version (if applicable).
    *   Relevant logs or screenshots if possible.

### Feature Requests
Have an idea for a new feature or an improvement to an existing one?
*   **Action**: Suggest new features through [GitHub Issues](https://github.com/HenryTheAddict/HenSurf/issues). Use the "Feature Request" template if available.
*   **Details**: Clearly describe the feature, why it would be useful, and any potential implementation ideas you might have.

### Pull Requests
We actively welcome your code contributions for bug fixes, improvements, or new features.
*   **Action**: Submit a Pull Request (PR) to the `main` branch.
*   **Guidelines**: Please follow the [Pull Request Process](#pull-request-process) outlined below.

## Development Setup

For instructions on how to set up your development environment, clone the repository, install dependencies, and build the browser, please refer to:
*   Our main [README.md](../README.md) for a quick start.
*   The detailed [DEVELOPMENT.md](docs/DEVELOPMENT.md) for a comprehensive guide.

## Coding Guidelines

To maintain consistency and quality, please adhere to the following guidelines:

*   **General Style**: Follow the existing coding style in the file(s) you are editing. Consistency is key.
*   **Shell Scripts (`.sh`)**:
    *   Please use `shellcheck` to lint your changes before submitting: `shellcheck your_script.sh`.
    *   Ensure scripts are robust and use `set -e` where appropriate.
    *   Use functions from `scripts/utils.sh` for logging and common tasks.
*   **Python Scripts (`.py`)**:
    *   Aim for PEP 8 compliance.
    *   Consider using linters like `flake8` or `pylint` to check your code.
*   **C++ (Chromium Source Modifications)**:
    *   Follow the [Chromium C++ Style Guide](https://chromium.googlesource.com/chromium/src/+/main/styleguide/c++/c++.md).
    *   Ensure changes are minimal and targeted. Patches should be as atomic as possible.
*   **Commit Messages**: Write clear and descriptive commit messages. See [DEVELOPMENT.md](docs/DEVELOPMENT.md) for more details on commit message best practices.

## Pull Request Process

1.  **Fork the Repository**: Click the "Fork" button at the top right of the [HenSurf GitHub page](https://github.com/HenryTheAddict/HenSurf).
2.  **Clone Your Fork**:
    ```bash
    git clone https://github.com/YOUR_USERNAME/HenSurf.git
    cd HenSurf
    ```
3.  **Create a New Branch**: Create a branch from `main` for your feature or bugfix.
    ```bash
    # For a new feature
    git checkout -b feature/your-descriptive-feature-name
    # For a bug fix
    git checkout -b bugfix/fix-for-that-specific-bug
    ```
4.  **Make Your Changes**: Implement your feature or fix the bug. Remember to:
    *   Follow the [Coding Guidelines](#coding-guidelines).
    *   Add or update tests if applicable.
    *   Update documentation if your changes affect usage, architecture, or the build process.
5.  **Commit Your Changes**: Commit your work with a clear commit message.
    ```bash
    git add .
    git commit -m "feat: Add amazing new feature X"
    # Or "fix: Resolve issue Y with component Z"
    ```
6.  **Push to Your Branch**: Push your changes to your forked repository.
    ```bash
    git push origin feature/your-descriptive-feature-name
    ```
7.  **Create a Pull Request (PR)**:
    *   Go to your fork on GitHub.
    *   Click the "Compare & pull request" button for the branch you just pushed.
    *   Ensure the base repository is `HenryTheAddict/HenSurf` and the base branch is `main`.
    *   Provide a clear title and a detailed description for your PR:
        *   Explain the purpose of your changes (what and why).
        *   If it fixes a GitHub issue, reference it (e.g., "Fixes #123").
        *   Outline how your changes have been tested.
8.  **CI Checks**: Ensure all Continuous Integration (CI) checks (GitHub Actions) pass on your PR. If they fail, review the logs and push necessary fixes to your branch.

## Code of Conduct

This project and everyone participating in it is governed by a Code of Conduct (link to be added if one is created, e.g., `CODE_OF_CONDUCT.md`). By participating, you are expected to uphold this code. Please report unacceptable behavior.

For now, we ask all contributors to be respectful and constructive in their interactions.

---

Thank you for contributing to HenSurf Browser!
