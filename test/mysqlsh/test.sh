#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'mysqlsh' Feature with no options.
#
# For more information, see: https://github.com/devcontainers/cli/blob/main/docs/features/test.md
#
# Eg:
# {
#    "image": "<..some-base-image...>",
#    "features": {
#      "mysqlsh": {}
#    },
#    "remoteUser": "root"
# }
#
# Thus, the value of all options will fall back to the default value in
# the Feature's 'devcontainer-feature.json'.
# For the 'mysqlsh' feature, that means VERSION=latest.
#
# This test can be run with the following command:
#
#    devcontainer features test          \
#               --features mysqlsh       \
#               --remote-user root       \
#               --skip-scenarios         \
#               --base-image ubuntu:jammy \
#               /path/to/this/repo

set -e

source dev-container-features-test-lib

check "mysqlsh binary is on PATH"            bash -c "command -v mysqlsh"
check "mysqlsh --version exits successfully" bash -c "mysqlsh --version 2>&1"
check "output contains version info"         bash -c "mysqlsh --version 2>&1 | grep -iE '(MySQL.?Shell|mysqlsh.+[Vv]er)'"
check "mysqlsh --help exits successfully"    bash -c "mysqlsh --help 2>&1"

reportResults
