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

On arm64, the exact version is resolved via the GitHub Tags API. If the API is unreachable (e.g., rate-limited or network restricted), the installer falls back to a built-in default version. A warning is printed to stderr in this case:

```
(*) GitHub API unavailable or no matching tag found. Using fallback version: 8.4.8
```

This is non-fatal — installation continues with the fallback version.

### arm64: GPG signature verification

For arm64 tarball installs, the installer verifies the downloaded archive with Oracle/MySQL GPG signatures.
It downloads:

- Signature: `https://dev.mysql.com/downloads/gpg/?file=<tarball>&p=43`
- Public keys: `RPM-GPG-KEY-mysql-2022`, `RPM-GPG-KEY-mysql-2025` from `https://repo.mysql.com/`

If signature or key retrieval fails, or signature verification fails, installation exits with an error.

### HTTPS proxy environments

If your environment requires an HTTPS proxy, set the `https_proxy` environment variable before building the container. The installer uses `curl` for all downloads.
