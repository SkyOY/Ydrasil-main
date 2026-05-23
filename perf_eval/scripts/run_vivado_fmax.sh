#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

mkdir -p "${EVAL_ROOT}/vivado/reports"

repo_root_win="${REPO_ROOT}"
eval_root_win="${EVAL_ROOT}"
if command -v wslpath >/dev/null 2>&1; then
    repo_root_win="$(wslpath -w "${REPO_ROOT}")"
    eval_root_win="$(wslpath -w "${EVAL_ROOT}")"
fi

freq_list="${FREQ_LIST:-150 175 200 225 250}"
tcl="${EVAL_ROOT}/vivado/run_fmax.tcl"
cmd_file="${EVAL_ROOT}/vivado/vivado_command.txt"

vivado_display="${VIVADO_CMD:-VIVADO_CMD}"
cat > "${cmd_file}" <<EOF_CMD
${vivado_display} -mode batch -source ${eval_root_win}\\vivado\\run_fmax.tcl -tclargs "${repo_root_win}" "${eval_root_win}" "${freq_list}"
EOF_CMD

if [ -z "${VIVADO_CMD:-}" ]; then
    echo "VIVADO_CMD is not set. Generated ${cmd_file} and ${tcl}."
    exit 0
fi

if command -v "${VIVADO_CMD}" >/dev/null 2>&1 || [ -x "${VIVADO_CMD}" ]; then
    "${VIVADO_CMD}" -mode batch -source "${tcl}" -tclargs "${repo_root_win}" "${eval_root_win}" "${freq_list}"
elif [[ "${VIVADO_CMD}" == *\\* ]] && command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c "\"${VIVADO_CMD}\" -mode batch -source \"${eval_root_win}\\vivado\\run_fmax.tcl\" -tclargs \"${repo_root_win}\" \"${eval_root_win}\" \"${freq_list}\""
elif [[ "${VIVADO_CMD}" == *\\* ]] && command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "& '${VIVADO_CMD}' -mode batch -source '${eval_root_win}\\vivado\\run_fmax.tcl' -tclargs '${repo_root_win}' '${eval_root_win}' '${freq_list}'"
else
    echo "Cannot execute VIVADO_CMD=${VIVADO_CMD}. Generated command in ${cmd_file}."
    exit 0
fi
