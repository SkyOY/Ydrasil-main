`ifndef CONFIG_SVH
`define CONFIG_SVH

`ifndef YDRASIL_MUL_IMPL_4CYCLE
`ifndef YDRASIL_MUL_IMPL_RADIX8
`define YDRASIL_MUL_IMPL_4CYCLE
`endif
`endif

`ifdef YDRASIL_MUL_IMPL_4CYCLE
`ifdef YDRASIL_MUL_IMPL_RADIX8
`error "Select only one multiplier implementation: YDRASIL_MUL_IMPL_4CYCLE or YDRASIL_MUL_IMPL_RADIX8"
`endif
`endif

`endif
