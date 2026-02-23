#!/bin/bash

# Scenario test: version=8.0 on ubuntu:jammy

set -e

source dev-container-features-test-lib

check "mysqlsh binary is on PATH"            bash -c "command -v mysqlsh"
check "mysqlsh --version exits successfully" bash -c "mysqlsh --version 2>&1"
check "output contains version info"         bash -c "mysqlsh --version 2>&1 | grep -iE '(MySQL.?Shell|mysqlsh.+[Vv]er)'"
check "version is 8.0.x"                     bash -c "mysqlsh --version 2>&1 | grep -E '8\.0\.[0-9]+'"
check "mysqlsh --help exits successfully"    bash -c "mysqlsh --help 2>&1"

reportResults
