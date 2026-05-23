#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

need_tool "${VERILATOR}"
need_tool "${BENDER}"

FLIST_FILE="${FLIST_DIR}/ydrasil_core_verilator.f"

(
    cd "${REPO_ROOT}/hw/ip/ydrasil_core"
    "${BENDER}" script flist-plus -t verilator | sed '/^+define+/d' > "${FLIST_FILE}"
)

"${VERILATOR}" \
    -cc --exe --sv \
    -DVERILATOR_CC \
    --Mdir "${SIM_BUILD_DIR}" \
    --build -o "${SIM_BIN}" \
    -MAKEFLAGS "-j$(nproc)" \
    -j "$(nproc)" \
    --top-module perf_core_tb \
    -Wno-fatal -Wno-TIMESCALEMOD -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-WIDTHCONCAT -Wno-UNOPTFLAT \
    -I"${REPO_ROOT}/hw/ip/ydrasil_core/rtl" \
    -f "${FLIST_FILE}" \
    "${EVAL_ROOT}/tb/perf_core_tb.sv" \
    "${EVAL_ROOT}/tb/perf_sim.cpp" \
    > "${LOG_DIR}/verilator_build.log" 2> "${LOG_DIR}/verilator_build.err.log"

write_metadata
echo "Built ${SIM_BIN}"
