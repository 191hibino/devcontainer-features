
# MySQL Shell (mysqlsh)

Installs MySQL Shell (mysqlsh). Supports Debian/Ubuntu on amd64/arm64.

## Example Usage

```json
"features": {
    "ghcr.io/191hibino/devcontainer-features/mysqlsh:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | MySQL Shell version series: 'latest'/'8.4' installs 8.4 LTS, '8.0' installs 8.0. | string | latest |

## Supported Platforms

| Architecture | OS |
|---|---|
| amd64 | Ubuntu 22.04 (jammy), Ubuntu 24.04 (noble), Debian 12 (bookworm) |
| arm64 | Ubuntu 22.04 (jammy), Ubuntu 24.04 (noble), Debian 12 (bookworm) |

## Known Limitations

- **Alpine Linux is not supported.** MySQL Shell does not provide Alpine-compatible packages.
- **RHEL/CentOS/Fedora/AlmaLinux/Rocky Linux are not supported.** Only Debian/Ubuntu are supported.
- **arm64 requires glibc 2.28 or later.** The Linux Generic tarball is linked against glibc 2.28. Older distributions may not be compatible.

## Troubleshooting

### arm64: GitHub API unavailable

On arm64, the exact version is resolved via the GitHub Releases API. If the API is unreachable (e.g., rate-limited or network restricted), the installer falls back to a built-in default version. A warning is printed to stderr in this case:

```
(*) GitHub API unavailable or no matching release found. Using fallback version: 8.4.8
```

This is non-fatal — installation continues with the fallback version.

### HTTPS proxy environments

If your environment requires an HTTPS proxy, set the `https_proxy` environment variable before building the container. The installer uses `curl` for all downloads.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/191hibino/devcontainer-features/blob/main/src/mysqlsh/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
