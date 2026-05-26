// `ifndef DEFINE_MEM_REG_SVH
// `define DEFINE_MEM_REG_SVH

// 内存和地址配置
`define ITCM_ADDR_WIDTH 12  // ITCM地址宽度，12位对应16KB
`define DTCM_ADDR_WIDTH 16  // DTCM地址宽度，16位对应256KB

// 内存映射地址
`define ITCM_BASE_ADDR 32'h8000_0000         // ITCM基地址
`define ITCM_SIZE (1 << `ITCM_ADDR_WIDTH)     // ITCM大小：16KB
`define DTCM_BASE_ADDR 32'h8010_0000 // DTCM基地址
`define DTCM_SIZE (1 << `DTCM_ADDR_WIDTH)     // DTCM大小：256KB

// 内存初始化控制
`ifndef INIT_ITCM
`define INIT_ITCM 1       // 控制ITCM是否初始化，1表示初始化，0表示不初始化
`endif
`ifndef ITCM_INIT_FILE
`define ITCM_INIT_FILE "hw/dv/test_data/mem_generated/rv32ui-p-add.mem"  // ITCM初始化文件路径
`endif
`ifndef INIT_DTCM
`define INIT_DTCM 1
`endif
`ifndef DTCM_INIT_FILE
`define DTCM_INIT_FILE "hw/dv/test_data/mem/dram_test.mem"
`endif
// 总线宽度定义
`define BUS_DATA_WIDTH 32
`define BUS_ADDR_WIDTH 32

`define INST_DATA_WIDTH 32
`define INST_ADDR_WIDTH 32

// 寄存器配置
`define REGS_ADDR_WIDTH 5
`define REGS_DATA_WIDTH 32
`define DOUBLE_REGS_WIDTH 64
`define REGS_NUM 32
`define CSR_ADDR_WIDTH 12

// CSR reg addr
`define CSR_CYCLE 12'hc00
`define CSR_TIME 12'hc01
`define CSR_INSTRET 12'hc02
`define CSR_CYCLEH 12'hc80
`define CSR_TIMEH 12'hc81
`define CSR_INSTRETH 12'hc82
`define CSR_MVENDORID 12'hf11
`define CSR_MARCHID 12'hf12
`define CSR_MIMPID 12'hf13
`define CSR_MHARTID 12'hf14
`define CSR_MTVEC 12'h305
`define CSR_MISA 12'h301
`define CSR_MEDELEG 12'h302
`define CSR_MIDELEG 12'h303
`define CSR_MCAUSE 12'h342
`define CSR_MEPC 12'h341
`define CSR_MTVAL 12'h343
`define CSR_MIP 12'h344
`define CSR_MIE 12'h304
`define CSR_MSTATUS 12'h300
`define CSR_MSTATUSH 12'h310
`define CSR_MCOUNTEREN 12'h306
`define CSR_MCOUNTINHIBIT 12'h320
`define CSR_MSCRATCH 12'h340
`define CSR_MCYCLE 12'hb00
`define CSR_MINSTRET 12'hb02
`define CSR_MCYCLEH 12'hb80
`define CSR_MINSTRETH 12'hb82
`define CSR_PMPCFG0 12'h3a0
`define CSR_PMPADDR0 12'h3b0
`define CSR_SATP 12'h180

`define TRAP_CAUSE_MISALIGNED_FETCH 32'd0
`define TRAP_CAUSE_ILLEGAL_INSN 32'd2
`define TRAP_CAUSE_BREAKPOINT 32'd3
`define TRAP_CAUSE_MACHINE_ECALL 32'd11


// `endif
