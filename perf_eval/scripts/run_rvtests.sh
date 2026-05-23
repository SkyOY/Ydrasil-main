#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

need_tool "${CC}"
need_tool "${OBJCOPY}"
need_tool "${NM}"

IFS=' ' read -r -a tests <<< "${RVTEST_LIST:-rv32ui:add rv32ui:addi rv32ui:beq rv32ui:bne rv32ui:jal rv32ui:lw rv32ui:sw rv32ui:ld_st rv32ui:st_ld rv32um:mul rv32um:div rv32um:rem}"

includes="-I${REPO_ROOT}/sw/include -I${REPO_ROOT}/verif/tests/riscv-tests/env -I${REPO_ROOT}/verif/tests/riscv-tests/isa/macros/scalar"

for item in "${tests[@]}"; do
    group="${item%%:*}"
    base="${item#*:}"
    name="${group}_${base}"
    src="${REPO_ROOT}/verif/tests/riscv-tests/isa/${group}/${base}.S"
    out="${ELF_DIR}/${group}"
    elf="${out}/elf/${name}.elf"
    ihex="${MEM_DIR}/${name}.ihex"
    itcm="${MEM_DIR}/${name}.itcm"
    dtcm="${MEM_DIR}/${name}.dtcm"

    [ -f "${src}" ] || die "missing rvtest source: ${src}"
    make -C "${REPO_ROOT}/sw" rv_comp_genmem \
        NAME="${name}" \
        SRC="${src}" \
        OUT_DIR="${out}" \
        COMP_MODE=rvtest \
        INCLUDES="${includes}" \
        REBUILD=1 \
        > "${LOG_DIR}/${name}.build.log" 2>&1

    "${PYTHON}" "${EVAL_ROOT}/scripts/elf_to_mem.py" \
        --elf "${elf}" \
        --objcopy "${OBJCOPY}" \
        --ihex "${ihex}" \
        --itcm "${itcm}" \
        --dtcm "${dtcm}"

    "${EVAL_ROOT}/scripts/run_one.sh" "${name}" "${elf}" "${itcm}" "${dtcm}" "${RVTEST_TIMEOUT_CYCLES:-200000}" >/dev/null
    echo "Ran ${name}"
done
