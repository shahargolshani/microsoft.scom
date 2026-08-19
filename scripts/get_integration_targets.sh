#!/usr/bin/env bash
# Reads changed file paths from stdin (one per line).
# Prints space-separated ansible-test windows-integration target names to stdout.
# Prints nothing if no relevant source files changed.
#
# Mapping rules:
#   plugins/modules/<name>.ps1 or .yml        → win_scom_<name>
#   plugins/modules/<name>_info.ps1 or .yml   → win_scom_<name>  (strip _info)
#   plugins/module_utils/*                    → ALL win_scom_* targets
#   tests/integration/targets/win_scom_<name> → win_scom_<name>
#
# Usage:
#   git diff --name-only BASE...HEAD | bash scripts/get_integration_targets.sh

set -euo pipefail

readonly MODULES_DIR="plugins/modules"
readonly MODULE_UTILS_DIR="plugins/module_utils"
readonly INTEGRATION_DIR="tests/integration/targets"

targets=""
run_all=false

add_target() {
    local target="$1"
    [[ -d "${INTEGRATION_DIR}/${target}" ]] || return 0
    # Skip if already in the list
    [[ " ${targets} " == *" ${target} "* ]] && return 0
    targets="${targets:+${targets} }${target}"
}

while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    # Any module_utils change → run ALL integration tests
    if [[ "$file" == "${MODULE_UTILS_DIR}/"* ]]; then
        run_all=true
        break
    fi

    # Module source file changed (.ps1 or .yml)
    if [[ "$file" == "${MODULES_DIR}/"*.ps1 || "$file" == "${MODULES_DIR}/"*.yml ]]; then
        filename=$(basename "$file")
        module_name="${filename%.*}"      # strip extension
        base_name="${module_name%_info}"  # strip _info suffix
        add_target "win_scom_${base_name}"
        continue
    fi

    # Integration test file changed directly
    if [[ "$file" == "${INTEGRATION_DIR}/win_scom_"* ]]; then
        rel="${file#"${INTEGRATION_DIR}/"}"
        add_target "${rel%%/*}"
        continue
    fi

done

if [[ "$run_all" == "true" ]]; then
    # Signal to caller: run all tests with no target filter
    echo "ALL"
else
    echo "${targets}"
fi
