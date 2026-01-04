# GitHub Actions CI/CD Guide

## Quick Start

### Download Pre-built Binaries

**Recommended:** Visit the [Releases page](https://github.com/cmcxn/skynet-mingw/releases) to download the latest stable build.

**Alternative:** Go to [Actions page](https://github.com/cmcxn/skynet-mingw/actions), select a successful workflow run, and download the artifact (available for 30 days).

### Create a New Release

To trigger an automated release:

```bash
# Tag your commit
git tag v1.0.0

# Push the tag to GitHub
git push origin v1.0.0
```

The workflow will automatically:
1. Build the project
2. Run tests
3. Package the binaries
4. Create a GitHub Release
5. Upload the package to the release

## Workflow Triggers

The workflow runs on:

- **Push to main/master** - Builds and uploads artifacts
- **Pull Requests** - Validates the build
- **Version tags (v*)** - Creates a GitHub Release
- **Manual dispatch** - Run from Actions tab

## What's Included

The `skynet-mingw-windows.zip` contains:

- **Executables:** skynet.exe
- **Core DLLs:** platform.dll, lua54.dll, skynet.dll
- **Runtime dependencies:** libgcc_s_seh-1.dll, libwinpthread-1.dll
- **Modules:** luaclib/, cservice/
- **Resources:** examples/, lualib/, service/, test/
- **Build info:** BUILD_INFO.txt (commit hash, build date)

## Installation

1. Download `skynet-mingw-windows.zip`
2. Extract to your preferred location
3. Run `skynet.exe examples/config` to test

No additional dependencies required - all DLLs are included!

## Troubleshooting

### Build Fails

Check the [Actions logs](https://github.com/cmcxn/skynet-mingw/actions) for detailed error messages.

### Release Not Created

Ensure:
- Tag format is `v*` (e.g., `v1.0.0`, `v2.3.1`)
- Build and tests passed successfully
- Repository has Actions enabled with release permissions

### Artifacts Expired

Artifacts are kept for 30 days. For permanent storage, create a release using version tags.

## Configuration

Workflow file: `.github/workflows/build-windows.yml`

To modify:
- **Build environment:** Edit `msystem` and `install` sections
- **Triggers:** Modify `on` section  
- **Build steps:** Edit `steps` section
- **Package contents:** Modify `Package release` step
- **Release details:** Edit `Create Release` step
