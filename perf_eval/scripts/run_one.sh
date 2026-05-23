#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

[ $# -ge 4 ] || die "usage: run_one.sh <name> <elf> <itcm> <dtcm> [timeout_cycles]"

name="$1"
elf="$2"
itcm="$3"
dtcm="$4"
timeout_cycles="${5:-2000000}"

[ -x "${SIM_BIN}" ] || "${EVAL_ROOT}/scripts/build_sim.sh"
[ -f "${elf}" ] || die "missing elf: ${elf}"
[ -f "${itcm}" ] || die "missing itcm image: ${itcm}"
[ -f "${dtcm}" ] || die "missing dtcm image: ${dtcm}"

tohost="$(tohost_addr "${elf}")"
cpp_timeout=$((timeout_cycles * 2 + 1000))
log="${LOG_DIR}/${name}.log"

"${SIM_BIN}" \
    "+test_name=${name}" \
    "+itcmfile=${itcm}" \
    "+dtcmfile=${dtcm}" \
    "+tohost_addr=${tohost}" \
    "+timeout_cycles=${timeout_cycles}" \
    "+cpp_timeout=${cpp_timeout}" \
    > "${log}" 2>&1

echo "${log}"
