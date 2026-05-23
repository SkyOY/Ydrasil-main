# Ydrasil Performance Evaluation

## Environment
- `bender`: bender 0.31.0
- `cc`: riscv64-elf-gcc (Arch Linux Repositories) 15.2.0
- `coremark_sha`: 1f483d5b8316753a742cbf5590caf5bd0a4e4777
- `cpu_mhz`: 150
- `eval_root`: /home/ydrasil/projects/Ydrasil-main/perf_eval
- `repo_root`: /home/ydrasil/projects/Ydrasil-main
- `verilator`: Verilator 5.048 2026-04-26 rev v5.048

## Throughput

- Pass: 12
- Fail: 1

| Group | Count | Avg IPC | Min IPC | Max IPC | MIPS @150MHz |
| --- | ---: | ---: | ---: | ---: | ---: |
| rv32ui | 9 | 0.8652 | 0.5671 | 0.9892 | 129.78 |
| rv32um | 3 | 0.4732 | 0.4648 | 0.4901 | 70.98 |

## Benchmarks

| Name | Status | Reason | Cycles | Insts | IPC | Log |
| --- | --- | --- | ---: | ---: | ---: | --- |
| coremark | FAIL | invalid_pc | 3655 | 3132 | 0.8569 | `out/logs/coremark.log` |
| rv32ui_add | PASS |  | 557 | 551 | 0.9892 | `out/logs/rv32ui_add.log` |
| rv32ui_addi | PASS |  | 316 | 310 | 0.9810 | `out/logs/rv32ui_addi.log` |
| rv32ui_beq | PASS |  | 405 | 395 | 0.9753 | `out/logs/rv32ui_beq.log` |
| rv32ui_bne | PASS |  | 409 | 400 | 0.9780 | `out/logs/rv32ui_bne.log` |
| rv32ui_jal | PASS |  | 121 | 115 | 0.9504 | `out/logs/rv32ui_jal.log` |
| rv32ui_ld_st | PASS |  | 1797 | 1019 | 0.5671 | `out/logs/rv32ui_ld_st.log` |
| rv32ui_lw | PASS |  | 429 | 351 | 0.8182 | `out/logs/rv32ui_lw.log` |
| rv32ui_st_ld | PASS |  | 741 | 539 | 0.7274 | `out/logs/rv32ui_st_ld.log` |
| rv32ui_sw | PASS |  | 752 | 602 | 0.8005 | `out/logs/rv32ui_sw.log` |
| rv32um_div | PASS |  | 327 | 152 | 0.4648 | `out/logs/rv32um_div.log` |
| rv32um_mul | PASS |  | 1112 | 545 | 0.4901 | `out/logs/rv32um_mul.log` |
| rv32um_rem | PASS |  | 327 | 152 | 0.4648 | `out/logs/rv32um_rem.log` |

## CoreMark
- Validation: FAIL
- Iterations: None
- Cycles: 3655

## Fmax / FPGA Resources
- Not run: vivado results not found
