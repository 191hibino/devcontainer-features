#!/bin/bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) 2025 191hibino
# Licensed under the MIT License. See LICENSE file.
#-------------------------------------------------------------------------------------------------------------
#
# Docs: https://dev.mysql.com/doc/mysql-shell/en/
#
# Installs MySQL Shell (mysqlsh) from the official MySQL repository.
#
# Supported OS:
#   - Debian/Ubuntu (amd64): MySQL APT repository
#   - Debian/Ubuntu (arm64): Linux Generic tarball
#
# Not supported:
#   - Alpine Linux
#   - RHEL/CentOS/Fedora/AlmaLinux/Rocky
#   - Architectures other than amd64 and arm64

set -euo pipefail

# Option injected as environment variable (option name uppercased)
VERSION="${VERSION:-"latest"}"

# Fallback versions used when GitHub API is unavailable (arm64)
FALLBACK_80="8.0.45"
FALLBACK_84="8.4.8"

# mysql-apt-config package version (update here when a new version is released)
MYSQL_APT_CONFIG_DEB="mysql-apt-config_0.8.36-1_all.deb"

print_info() {
    echo -e "\n(*) $*\n"
}

print_error() {
    echo -e "\n(!) ERROR: $*\n" >&2
}

# Clean package manager caches to reduce image layer size
cleanup() {
    rm -rf /var/lib/apt/lists/*
}

# Resolve VERSION option to a MySQL series name used in repository paths
# Returns: "8.0" or "8.4"
resolve_series() {
    local ver="${1:-latest}"
    case "${ver}" in
        latest) echo "8.4" ;;
        8.0)    echo "8.0" ;;
        8.4)    echo "8.4" ;;
        *)
            print_error "Unsupported version: '${ver}'. Valid values: latest, 8.0, 8.4"
            exit 1
            ;;
    esac
}

# -------------------------------------------------------
# arm64: Resolve exact version via GitHub Tags API
# -------------------------------------------------------
get_exact_version_arm64() {
    local series="${1}"  # "8.0" or "8.4"

    local fallback
    case "${series}" in
        8.0) fallback="${FALLBACK_80}" ;;
        8.4) fallback="${FALLBACK_84}" ;;
    esac

    # Use per_page=100 to reduce the risk of the target tag falling off page 1
    local api_url="https://api.github.com/repos/mysql/mysql-shell/tags?per_page=100"
    local exact_ver
    exact_ver=$(curl -fsSL --connect-timeout 10 "${api_url}" 2>/dev/null \
        | grep '"name"' \
        | grep "\"${series}\." \
        | head -1 \
        | sed 's/.*"\([^"]*\)".*/\1/' \
        || true)

    if [ -z "${exact_ver}" ]; then
        # Use stderr so this message is not captured by command substitution
        echo -e "\n(*) GitHub API unavailable or no matching tag found. Using fallback version: ${fallback}\n" >&2
        echo "${fallback}"
    else
        echo "${exact_ver}"
    fi
}

# -------------------------------------------------------
# arm64: Install from Linux Generic tarball
# -------------------------------------------------------
install_arm64() {
    local series="${1}"

    print_info "Detected arm64. Installing MySQL Shell via Linux Generic tarball."

    # Install required tools
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends curl ca-certificates tar gnupg

    local exact_ver
    exact_ver="$(get_exact_version_arm64 "${series}")"
    print_info "Installing MySQL Shell ${exact_ver} (arm64)"

    local tarball="mysql-shell-${exact_ver}-linux-glibc2.28-arm-64bit.tar.gz"
    local url="https://dev.mysql.com/get/Downloads/MySQL-Shell/${tarball}"
    local tmpfile
    tmpfile="$(mktemp /tmp/mysqlsh-XXXXXX.tar.gz)"

    curl -fsSL --connect-timeout 30 "${url}" -o "${tmpfile}"

    # Verify downloaded tarball using Oracle/MySQL GPG signature
    local sig_url
    sig_url="https://dev.mysql.com/downloads/gpg/?file=${tarball}&p=43"
    local sig_file
    sig_file="$(mktemp /tmp/mysqlsh-XXXXXX.sig.asc)"
    local key_2022
    key_2022="$(mktemp /tmp/mysqlsh-key-2022-XXXXXX.asc)"
    local key_2025
    key_2025="$(mktemp /tmp/mysqlsh-key-2025-XXXXXX.asc)"
    local gpg_home
    gpg_home="$(mktemp -d /tmp/mysqlsh-gnupg-XXXXXX)"
    chmod 700 "${gpg_home}"

    if ! curl -fsSL --connect-timeout 30 "${sig_url}" -o "${sig_file}"; then
        print_error "Failed to download GPG signature: ${sig_url}"
        rm -f "${tmpfile}" "${sig_file}" "${key_2022}" "${key_2025}"
        rm -rf "${gpg_home}"
        exit 1
    fi

    if ! curl -fsSL --connect-timeout 30 "https://repo.mysql.com/RPM-GPG-KEY-mysql-2022" -o "${key_2022}" \
        || ! curl -fsSL --connect-timeout 30 "https://repo.mysql.com/RPM-GPG-KEY-mysql-2025" -o "${key_2025}"; then
        print_error "Failed to download MySQL GPG public keys."
        rm -f "${tmpfile}" "${sig_file}" "${key_2022}" "${key_2025}"
        rm -rf "${gpg_home}"
        exit 1
    fi

    if ! gpg --batch --homedir "${gpg_home}" --import "${key_2022}" "${key_2025}" >/dev/null 2>&1; then
        print_error "Failed to import MySQL GPG public keys."
        rm -f "${tmpfile}" "${sig_file}" "${key_2022}" "${key_2025}"
        rm -rf "${gpg_home}"
        exit 1
    fi

    print_info "Verifying GPG signature..."
    if ! gpg --batch --homedir "${gpg_home}" --verify "${sig_file}" "${tmpfile}" >/dev/null 2>&1; then
        print_error "GPG signature verification failed for ${tarball}."
        rm -f "${tmpfile}" "${sig_file}" "${key_2022}" "${key_2025}"
        rm -rf "${gpg_home}"
        exit 1
    fi
    print_info "GPG signature OK."

    rm -f "${sig_file}" "${key_2022}" "${key_2025}"
    rm -rf "${gpg_home}"

    tar -xzf "${tmpfile}" -C /opt/
    rm -f "${tmpfile}"

    ln -sf "/opt/mysql-shell-${exact_ver}-linux-glibc2.28-arm-64bit/bin/mysqlsh" /usr/local/bin/mysqlsh

    cleanup
}

# -------------------------------------------------------
# amd64: Debian/Ubuntu via mysql-apt-config + APT
# -------------------------------------------------------
install_debian_amd64() {
    local series="${1}"
    local distro="${2}"      # "ubuntu" or "debian"
    local codename="${3}"    # e.g. "jammy", "bookworm"

    print_info "Installing MySQL Shell on ${distro}/${codename} (series: ${series}) via APT"

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        gnupg \
        ca-certificates \
        debconf-utils \
        lsb-release

    # Map series to mysql-apt-config server selection value
    local server_selection
    case "${series}" in
        8.0) server_selection="mysql-8.0" ;;
        *)   server_selection="mysql-8.4-lts" ;;
    esac

    # Pre-seed debconf so mysql-apt-config runs non-interactively
    echo "mysql-apt-config mysql-apt-config/select-server select ${server_selection}" \
        | debconf-set-selections
    echo "mysql-apt-config mysql-apt-config/select-tools select Enabled" \
        | debconf-set-selections
    echo "mysql-apt-config mysql-apt-config/select-preview select Disabled" \
        | debconf-set-selections
    echo "mysql-apt-config mysql-apt-config/select-product select Ok" \
        | debconf-set-selections

    # Download and install mysql-apt-config (sets up GPG key + sources.list)
    local tmpfile
    tmpfile="$(mktemp /tmp/mysqlsh-apt-config-XXXXXX.deb)"
    curl -fsSL --connect-timeout 30 "https://dev.mysql.com/get/${MYSQL_APT_CONFIG_DEB}" -o "${tmpfile}"
    dpkg --install "${tmpfile}"
    rm -f "${tmpfile}"

    apt-get update -y
    apt-get install -y --no-install-recommends mysql-shell

    cleanup
}

# -------------------------------------------------------
# Main
# -------------------------------------------------------
print_info "Installing MySQL Shell (version option: ${VERSION})"

# Initial cleanup
cleanup

# Detect architecture
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64)  ARCH_TYPE="amd64" ;;
    aarch64) ARCH_TYPE="arm64" ;;
    *)
        print_error "Unsupported architecture: ${ARCH}. Only amd64 (x86_64) and arm64 (aarch64) are supported."
        exit 1
        ;;
esac

# Detect OS
if [ ! -f /etc/os-release ]; then
    print_error "Cannot detect OS: /etc/os-release not found."
    exit 1
fi
# Save VERSION before sourcing /etc/os-release because it also defines VERSION
# (e.g. Ubuntu sets VERSION="22.04.5 LTS (Jammy Jellyfish)")
_MYSQLSH_VERSION="${VERSION}"
# shellcheck source=/dev/null
. /etc/os-release
VERSION="${_MYSQLSH_VERSION}"
unset _MYSQLSH_VERSION
OS_ID="${ID}"
OS_ID_LIKE="${ID_LIKE:-}"
OS_VERSION_CODENAME="${VERSION_CODENAME:-}"

# Resolve version series
SERIES="$(resolve_series "${VERSION}")"

# arm64: always use generic tarball
if [ "${ARCH_TYPE}" = "arm64" ]; then
    install_arm64 "${SERIES}"
else
    # amd64: use APT based on distro
    case "${OS_ID}" in
        ubuntu|debian)
            if [ -z "${OS_VERSION_CODENAME}" ]; then
                OS_VERSION_CODENAME="$(lsb_release -cs 2>/dev/null || true)"
            fi
            if [ -z "${OS_VERSION_CODENAME}" ]; then
                print_error "Cannot determine distribution codename."
                exit 1
            fi
            install_debian_amd64 "${SERIES}" "${OS_ID}" "${OS_VERSION_CODENAME}"
            ;;
        alpine)
            print_error "Alpine Linux is not supported. MySQL Shell does not provide Alpine packages."
            print_error "Please use a Debian/Ubuntu base image."
            exit 1
            ;;
        *)
            # Fallback: check ID_LIKE for Debian/Ubuntu derivatives
            if echo "${OS_ID_LIKE}" | grep -qiE "(debian|ubuntu)"; then
                if [ -z "${OS_VERSION_CODENAME}" ]; then
                    OS_VERSION_CODENAME="$(lsb_release -cs 2>/dev/null || true)"
                fi
                if [ -n "${OS_VERSION_CODENAME}" ]; then
                    install_debian_amd64 "${SERIES}" "debian" "${OS_VERSION_CODENAME}"
                else
                    print_error "Unsupported Debian-like distribution without a codename: ${OS_ID}"
                    exit 1
                fi
            else
                print_error "Unsupported distribution: ${OS_ID}. Only Debian/Ubuntu are supported."
                exit 1
            fi
            ;;
    esac
fi

# Verify installation
print_info "Verifying MySQL Shell installation..."
mysqlsh --version

print_info "MySQL Shell installation complete."
