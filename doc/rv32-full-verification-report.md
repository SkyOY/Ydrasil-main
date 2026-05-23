# RV32 Full Verification Report

Run date: 2026-05-23

## Summary

This report covers every `rv32*` directory under `verif/tests/riscv-tests/isa`.

- Total RV32 source tests: 157
- Compiled and simulated: 76
- Passed simulation: 65
- Failed simulation: 11
- Failed compilation: 81

Conclusion: the full RV32 test tree does not pass with the current repository configuration.

## Results by Type

| Type | Source tests | Simulated | PASS | Sim FAIL | Compile FAIL |
| --- | ---: | ---: | ---: | ---: | ---: |
| `rv32mi` | 16 | 16 | 10 | 6 | 0 |
| `rv32si` | 6 | 6 | 2 | 4 | 0 |
| `rv32ua` | 10 | 0 | 0 | 0 | 10 |
| `rv32uc` | 1 | 1 | 0 | 1 | 0 |
| `rv32ud` | 11 | 0 | 0 | 0 | 11 |
| `rv32uf` | 11 | 0 | 0 | 0 | 11 |
| `rv32ui` | 42 | 42 | 42 | 0 | 0 |
| `rv32um` | 8 | 8 | 8 | 0 | 0 |
| `rv32uzba` | 3 | 0 | 0 | 0 | 3 |
| `rv32uzbb` | 18 | 3 | 3 | 0 | 15 |
| `rv32uzbc` | 3 | 0 | 0 | 0 | 3 |
| `rv32uzbkb` | 5 | 0 | 0 | 0 | 5 |
| `rv32uzbkx` | 2 | 0 | 0 | 0 | 2 |
| `rv32uzbs` | 8 | 0 | 0 | 0 | 8 |
| `rv32uzfh` | 11 | 0 | 0 | 0 | 11 |
| `rv32uzicond` | 2 | 0 | 0 | 0 | 2 |

## Simulation Failures

These tests compiled to ITCM/DTCM memory images, ran in Verilator, and produced `TEST_FAIL`.

| Test | Cycles | Instructions | IPC |
| --- | ---: | ---: | ---: |
| `rv32mi_csr` | 251 | 231 | 0.9203 |
| `rv32mi_illegal` | 170 | 150 | 0.8824 |
| `rv32mi_ma_fetch` | 176 | 156 | 0.8864 |
| `rv32mi_mcsr` | 173 | 153 | 0.8844 |
| `rv32mi_sbreak` | 200 | 175 | 0.8750 |
| `rv32mi_shamt` | 176 | 155 | 0.8807 |
| `rv32si_csr` | 188 | 168 | 0.8936 |
| `rv32si_dirty` | 201 | 173 | 0.8607 |
| `rv32si_ma_fetch` | 182 | 162 | 0.8901 |
| `rv32si_sbreak` | 173 | 151 | 0.8728 |
| `rv32uc_rvc` | 181 | 161 | 0.8895 |

## Compile Failures

The following test groups did not generate memory images under the current build configuration.

| Type | Failed tests |
| --- | --- |
| `rv32ua` | `amoadd_w`, `amoand_w`, `amomax_w`, `amomaxu_w`, `amomin_w`, `amominu_w`, `amoor_w`, `amoswap_w`, `amoxor_w`, `lrsc` |
| `rv32ud` | `fadd`, `fclass`, `fcmp`, `fcvt`, `fcvt_w`, `fdiv`, `fmadd`, `fmin`, `ldst`, `move`, `recoding` |
| `rv32uf` | `fadd`, `fclass`, `fcmp`, `fcvt`, `fcvt_w`, `fdiv`, `fmadd`, `fmin`, `ldst`, `move`, `recoding` |
| `rv32uzba` | `sh1add`, `sh2add`, `sh3add` |
| `rv32uzbb` | `andn`, `clz`, `cpop`, `ctz`, `max`, `maxu`, `min`, `minu`, `orc_b`, `orn`, `rev8`, `rol`, `ror`, `rori`, `xnor` |
| `rv32uzbc` | `clmul`, `clmulh`, `clmulr` |
| `rv32uzbkb` | `brev8`, `pack`, `packh`, `unzip`, `zip` |
| `rv32uzbkx` | `xperm4`, `xperm8` |
| `rv32uzbs` | `bclr`, `bclri`, `bext`, `bexti`, `binv`, `binvi`, `bset`, `bseti` |
| `rv32uzfh` | `fadd`, `fclass`, `fcmp`, `fcvt`, `fcvt_w`, `fdiv`, `fmadd`, `fmin`, `ldst`, `move`, `recoding` |
| `rv32uzicond` | `czero_eqz`, `czero_nez` |

The compile failures are consistent with extensions that are not enabled or not implemented in the current flow, including A/atomic, F/D/floating-point, C/compressed, B/bitmanip subsets, Zfh, and Zicond.

## Commands Used

```sh
RV32_TYPES="$(find verif/tests/riscv-tests/isa -maxdepth 1 -type d -name 'rv32*' -printf '%f\n' | sort | paste -sd' ' -)"

make -k -j"$(nproc)" rv_test_comp_genmem RVTESTS_TYPE="$RV32_TYPES" \
  > /tmp/ydrasil_rv32_all_compile.log 2>&1

make comp VERILATOR_TRACE=0 \
  > /tmp/ydrasil_rv32_all_sim.log 2>&1

make -k -j1 rv_test_sim_all RVTESTS_TYPE="$RV32_TYPES" VERILATOR_TRACE=0 \
  >> /tmp/ydrasil_rv32_all_sim.log 2>&1
```

## Artifacts

- Compile log: `/tmp/ydrasil_rv32_all_compile.log`
- Simulation driver log: `/tmp/ydrasil_rv32_all_sim.log`
- Per-test status files: `build/rvtest_results/<type>/*.status`
- Per-test simulation logs: `build/rvtest_results/<type>/*.log`

## Assumptions

- The test compilation flow uses the current repository defaults, primarily `rv32im_zicsr_zifencei` for software test builds.
- Unsupported extension tests are counted as not passing when they fail to compile or fail simulation.
- Simulation failures were confirmed from per-test logs containing `TEST_FAIL`.
