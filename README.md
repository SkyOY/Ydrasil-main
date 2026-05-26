# Ydrasil

Ydrasil 是一个 RV32IM_Zicsr 单核处理器工程，包含 RTL、片上存储器、仿真测试、riscv-tests 构建流、性能评估脚本和 FPGA 顶层相关文件。当前默认仿真工具为 Verilator，IP 清单由 Bender 管理。

## 工程内容

| 路径 | 内容 |
| --- | --- |
| `hw/ip/ydrasil_core` | CPU 核心 RTL、译码、执行、访存、写回、CSR/CLINT、乘除法单元和 core 级 testbench。 |
| `hw/ip/ydrmem` | ITCM/DTCM/ROM/RAM 存储器 IP。 |
| `hw/ip/jyd_fpga` | FPGA 顶层、外设桥、UART、数码管、计数器等板级封装。 |
| `hw/ip/Xilinx_ip_wrapper` | Xilinx 存储器 wrapper。 |
| `hw/dv` | Verilator、VCS、Icarus Verilog 仿真 Makefile 和 C++ 驱动。 |
| `sw` | RISC-V 裸机测试编译、链接脚本、ELF/dump/mem 镜像生成。 |
| `verif/tests` | riscv-tests、riscv-arch-test 和自定义测试资源。 |
| `verif/sim` | 日志/trace 处理脚本。 |
| `perf_eval` | 自包含性能评估流程，生成 rvtests/CoreMark/Vivado Fmax 报告。 |
| `FPGA` | Vivado 工程、IP 配置、约束和 COE 初始化文件。 |
| `doc` | RV32 验证报告和指令相关文档。 |

核心 RTL 清单见 `hw/ip/ydrasil_core/Bender.yml`。当前 core 依赖 `ydrasil::memory`，FPGA 顶层 `jyd_fpga` 依赖 `ydrasil::core`。

## 当前进展

- ISA/软件配置默认为 `rv32im_zicsr`，ABI 为 `ilp32`。
- `rv32ui` 和 `rv32um` 是主回归集合，默认 `RVTESTS_TYPE := rv32ui rv32um`。
- `doc/rv32-full-verification-report.md` 记录了全 RV32 测试树状态：`rv32ui` 42/42 通过，`rv32um` 8/8 通过；A/F/D/C/B/Zfh/Zicond 等未实现或未开启扩展相关测试不在当前支持范围内。
- 当前乘法单元支持可配置实现：
  - 默认 `MUL_IMPL=4cycle`，使用 4 拍 17x17 带符号半字部分积多周期乘法。
  - `MUL_IMPL=radix8` 保留原 radix8 多周期实现，用于兼容和性能对比。
- 最近验证结果：
  - `make test_all RVTESTS_TYPE=rv32um VERILATOR_TRACE=0 MUL_IMPL=4cycle` 通过。
  - `make test_all RVTESTS_TYPE=rv32um VERILATOR_TRACE=0 MUL_IMPL=radix8` 通过。
  - `cd perf_eval && RVTEST_LIST='rv32um:mul' MUL_IMPL=4cycle make rvtests` 通过，`rv32um_mul` 为 755 cycles。
- 默认 4 拍乘法相比 radix8 降低了 `rv32um` 乘法类测试周期：core 回归中 `mul` 为 815 cycles，`mulh/mulhsu/mulhu` 为 807 cycles；radix8 对应约 1172/1150 cycles。

## 环境依赖

常用工具：

- `bender`
- `verilator`
- `riscv64-elf-gcc`
- `riscv64-elf-objcopy`
- `riscv64-elf-objdump`
- `riscv64-elf-newlib`
- `spike`
- `gtkwave`
- 可选：`vcs`、`iverilog`、Vivado

仓库提供 `make check_deps`，会按当前系统包管理器检查这些工具是否存在。

## 关键配置

主要配置在 `config.mk`：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SIM_TOOL` | `verilator` | RTL 仿真后端，可选 Make 流程包括 Verilator/VCS/Icarus。 |
| `IP` | `ydrasil_core` | 当前仿真的 IP。 |
| `VERILATOR_MOD` | `cc` | Verilator C++ 驱动模式。 |
| `VERILATOR_TRACE` | `1` | 是否生成波形；回归建议设为 `0`。 |
| `USE_BENDER` | `1` | 是否通过 Bender 生成文件清单。 |
| `MUL_IMPL` | `4cycle` | 乘法实现选择：`4cycle` 或 `radix8`。 |
| `RISCV_PREFIX` | `riscv64-elf` | RISC-V 工具链前缀。 |
| `ARCH` | `rv32im_zicsr` | 软件编译 ISA。 |
| `ABI` | `ilp32` | 软件 ABI。 |
| `RVTESTS_TYPE` | `rv32ui rv32um` | 默认回归测试集合。 |

乘法实现宏定义在 `hw/ip/ydrasil_core/rtl/config.svh`：

- `YDRASIL_MUL_IMPL_4CYCLE`
- `YDRASIL_MUL_IMPL_RADIX8`

两个宏不能同时定义。未显式定义时默认启用 `YDRASIL_MUL_IMPL_4CYCLE`。

## 常用命令

编译默认仿真模型：

```sh
make comp VERILATOR_TRACE=0
```

运行默认单个仿真：

```sh
make sim VERILATOR_TRACE=0
```

运行默认 `rv32ui rv32um` 回归：

```sh
make test_all VERILATOR_TRACE=0
```

只运行 RV32M 回归：

```sh
make test_all RVTESTS_TYPE=rv32um VERILATOR_TRACE=0
```

切换 radix8 乘法实现：

```sh
make test_all RVTESTS_TYPE=rv32um VERILATOR_TRACE=0 MUL_IMPL=radix8
```

重新生成测试 ELF 和 ITCM/DTCM 镜像：

```sh
make rv_test_comp_genmem_rebuild RVTESTS_TYPE=rv32ui
```

查看波形：

```sh
make full
make wave
```

## 性能评估

`perf_eval` 是独立评估入口，生成物集中在 `perf_eval/build` 和 `perf_eval/out`：

```sh
cd perf_eval
make smoke
make rvtests RVTEST_LIST='rv32um:mul'
make coremark
make report
```

运行完整性能评估但跳过 Vivado：

```sh
cd perf_eval
make all RUN_VIVADO=0
```

Vivado Fmax 评估：

```sh
cd perf_eval
make vivado
make report
```

WSL 下使用 Windows Vivado 时可显式指定：

```sh
cd perf_eval
VIVADO_CMD='C:\Xilinx\Vivado\2024.2\bin\vivado.bat' make vivado
```

输出文件包括：

- `perf_eval/out/report.md`
- `perf_eval/out/results.json`
- `perf_eval/out/logs/*.log`
- `perf_eval/vivado/reports/*`

## 内存与测试镜像

软件构建采用 Harvard 分离镜像：

- ITCM：`.text`、`.rodata`、`.tohost`
- DTCM：`.data`、`.sdata`、`.bss`、`.sbss`

`sw/Makefile` 会生成：

- `*.elf`
- `*.dump`
- `*.itcm`
- `*.dtcm`

仿真通过 plusargs 加载镜像：

- `+itcmfile=<path>`
- `+dtcmfile=<path>`

## 当前限制

- 当前主支持范围是 RV32I、RV32M 和 Zicsr 相关基础能力。
- 全 RV32 测试树中，A/atomic、F/D 浮点、C 压缩指令、B 位操作子集、Zfh、Zicond 等扩展相关用例未作为当前通过目标。
- Verilator 编译时仍会报告若干 `ydrasil_load_store_unit.sv` 的宽度告警；这些告警不来自乘法改动。
- `perf_eval/out` 下已有历史报告文件，重新运行性能脚本会刷新这些输出。

## 清理

清理顶层构建产物：

```sh
make clean
```

清理性能评估产物：

```sh
cd perf_eval
make clean
```
