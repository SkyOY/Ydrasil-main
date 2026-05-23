# Ydrasil Performance Evaluation

This directory is intentionally self-contained. Scripts here read the parent
Ydrasil RTL and software sources, but all generated binaries, memory images,
logs, Vivado work products, and reports stay under `perf_eval/`.

## Quick Start

```sh
cd perf_eval
make smoke
make all RUN_VIVADO=0
```

To run timing with Windows Vivado from WSL, set `VIVADO_CMD` explicitly:

```sh
VIVADO_CMD='C:\Xilinx\Vivado\2024.2\bin\vivado.bat' make vivado
make report
```

Outputs:

- `out/report.md`
- `out/results.json`
- `out/logs/*.log`
- `vivado/reports/*`

## Notes

- The CoreMark source is pinned under `third_party/coremark`.
- CoreMark timing uses the core `cycle/cycleh` counter. The report computes
  CoreMark/MHz as `iterations * 1e6 / cycles`.
- The Verilator testbench finishes when the program writes a non-zero value to
  its `tohost` symbol. A value of `1` is treated as pass.
- A failing `TOHOST=0xfffffffe` means the core jumped outside the implemented
  ITCM/DTCM address ranges; `TOHOST=0xffffffff` means the testbench timeout hit.
