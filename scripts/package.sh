#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${THEOS:?Set THEOS to your Theos checkout}"
scheme=${1:-rootless}
case "$scheme" in rootless) args=(THEOS_PACKAGE_SCHEME=rootless);; rootful) args=(THEOS_PACKAGE_SCHEME=);; *) echo 'Expected rootless or rootful' >&2; exit 1;; esac
bash scripts/build-go.sh
make clean
make -k package FINALPACKAGE=1 "${args[@]}"
