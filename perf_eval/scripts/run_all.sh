#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

"${EVAL_ROOT}/scripts/build_sim.sh"
"${EVAL_ROOT}/scripts/run_rvtests.sh"
"${EVAL_ROOT}/scripts/run_coremark.sh"

if [ "${RUN_VIVADO:-1}" = "1" ]; then
    "${EVAL_ROOT}/scripts/run_vivado_fmax.sh" || true
fi

"${EVAL_ROOT}/scripts/parse_results.py"
echo "Report: ${OUT_DIR}/report.md"
