#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVAL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${EVAL_ROOT}/.." && pwd)"

BUILD_DIR="${EVAL_ROOT}/build"
OUT_DIR="${EVAL_ROOT}/out"
LOG_DIR="${OUT_DIR}/logs"
MEM_DIR="${BUILD_DIR}/mem"
ELF_DIR="${BUILD_DIR}/elf"
FLIST_DIR="${BUILD_DIR}/flist"
SIM_BUILD_DIR="${BUILD_DIR}/verilator"
SIM_BIN="${BUILD_DIR}/perf_core_sim"

COREMARK_DIR="${EVAL_ROOT}/third_party/coremark"
COREMARK_SHA="1f483d5b8316753a742cbf5590caf5bd0a4e4777"

RISCV_PREFIX="${RISCV_PREFIX:-riscv64-elf}"
CC="${CC:-${RISCV_PREFIX}-gcc}"
OBJCOPY="${OBJCOPY:-${RISCV_PREFIX}-objcopy}"
OBJDUMP="${OBJDUMP:-${RISCV_PREFIX}-objdump}"
NM="${NM:-${RISCV_PREFIX}-nm}"
VERILATOR="${VERILATOR:-verilator}"
BENDER="${BENDER:-bender}"
PYTHON="${PYTHON:-python3}"

ARCH="${ARCH:-rv32im_zicsr}"
ABI="${ABI:-ilp32}"
CPU_MHZ="${CPU_MHZ:-150}"

mkdir -p "${BUILD_DIR}" "${OUT_DIR}" "${LOG_DIR}" "${MEM_DIR}" "${ELF_DIR}" "${FLIST_DIR}" "${SIM_BUILD_DIR}"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

need_tool() {
    command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"
}

tohost_addr() {
    local elf="$1"
    local addr
    addr="$("${NM}" -n "${elf}" | awk '$3 == "tohost" {print $1; exit}')"
    [ -n "${addr}" ] || die "could not find tohost symbol in ${elf}"
    printf "0x%s\n" "${addr}"
}

write_metadata() {
    {
        echo "repo_root=${REPO_ROOT}"
        echo "eval_root=${EVAL_ROOT}"
        echo "coremark_sha=${COREMARK_SHA}"
        echo "cpu_mhz=${CPU_MHZ}"
        echo "cc=$("${CC}" --version | sed -n '1p')"
        echo "verilator=$("${VERILATOR}" --version | sed -n '1p')"
        echo "bender=$("${BENDER}" --version | sed -n '1p')"
    } > "${OUT_DIR}/metadata.env"
}
