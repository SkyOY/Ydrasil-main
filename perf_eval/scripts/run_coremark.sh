#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

elf="$("${EVAL_ROOT}/scripts/build_coremark.sh")"
itcm="${MEM_DIR}/coremark.itcm"
dtcm="${MEM_DIR}/coremark.dtcm"
"${EVAL_ROOT}/scripts/run_one.sh" "coremark" "${elf}" "${itcm}" "${dtcm}" "${COREMARK_TIMEOUT_CYCLES:-50000000}" >/dev/null
echo "Ran coremark"
