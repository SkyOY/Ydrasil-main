#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

need_tool "${CC}"
need_tool "${OBJCOPY}"
need_tool "${OBJDUMP}"

[ -d "${COREMARK_DIR}/.git" ] || die "CoreMark is missing at ${COREMARK_DIR}"
actual_sha="$(git -C "${COREMARK_DIR}" rev-parse HEAD)"
[ "${actual_sha}" = "${COREMARK_SHA}" ] || die "CoreMark SHA mismatch: ${actual_sha}, expected ${COREMARK_SHA}"

iterations="${COREMARK_ITERATIONS:-10}"
total_data_size="${COREMARK_TOTAL_DATA_SIZE:-2000}"
name="coremark"
out="${ELF_DIR}/coremark"
mkdir -p "${out}"
elf="${out}/${name}.elf"
map="${out}/${name}.map"
dump="${out}/${name}.dump"
ihex="${MEM_DIR}/${name}.ihex"
itcm="${MEM_DIR}/${name}.itcm"
dtcm="${MEM_DIR}/${name}.dtcm"

cflags=(
    -march="${ARCH}"
    -mabi="${ABI}"
    -nostdlib
    -nostartfiles
    -static
    -mcmodel=medany
    -Os
    -ffunction-sections
    -fdata-sections
    -fno-builtin
    -fno-common
    -Wall
    -Wno-implicit-function-declaration
    -I"${COREMARK_DIR}"
    -I"${EVAL_ROOT}/ports/coremark"
    -DITERATIONS="${iterations}"
    -DPERFORMANCE_RUN=1
    -DTOTAL_DATA_SIZE="${total_data_size}"
    -DMAIN_HAS_NOARGC=1
    -DMAIN_HAS_NORETURN=1
    "-DFLAGS_STR=\"-Os -ffunction-sections -fdata-sections\""
)

sources=(
    "${EVAL_ROOT}/ports/coremark/crt0.S"
    "${EVAL_ROOT}/ports/coremark/core_portme.c"
    "${EVAL_ROOT}/ports/coremark/ee_printf.c"
    "${COREMARK_DIR}/core_list_join.c"
    "${COREMARK_DIR}/core_main.c"
    "${COREMARK_DIR}/core_matrix.c"
    "${COREMARK_DIR}/core_state.c"
    "${COREMARK_DIR}/core_util.c"
)

"${CC}" "${cflags[@]}" "${sources[@]}" \
    -T "${EVAL_ROOT}/ports/coremark/link_coremark.ld" \
    -Wl,--gc-sections \
    -Wl,-Map="${map}" \
    -lgcc \
    -o "${elf}" \
    > "${LOG_DIR}/coremark.build.log" 2>&1

"${OBJDUMP}" -D "${elf}" > "${dump}"
"${PYTHON}" "${EVAL_ROOT}/scripts/elf_to_mem.py" \
    --elf "${elf}" \
    --objcopy "${OBJCOPY}" \
    --ihex "${ihex}" \
    --itcm "${itcm}" \
    --dtcm "${dtcm}"

echo "${elf}"
