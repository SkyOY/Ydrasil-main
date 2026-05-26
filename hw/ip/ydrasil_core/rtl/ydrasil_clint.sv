/*         
 The MIT License (MIT)

 Copyright © 2025 Yusen Wang @yusen.w@qq.com
                                                                         
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
                                                                         
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
                                                                         
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

`include "define_mem_reg.svh"
`include "define_decode.svh"

module ydrasil_clint (

    input wire clk,
    input wire rst_n,

    // from id/ex
    input wire [`INST_ADDR_WIDTH-1:0] instr_addr_i,

    // kept for interface compatibility
    input wire                        ex_branch_jump_i,
    input wire [`INST_ADDR_WIDTH-1:0] ex_branch_target_i,
    
    input wire [`OP_SYS_INFO_WIDTH-1:0] sys_op_info_i,
    input wire                          sys_op_i,

    input wire                          trap_valid_i,
    input wire [`REGS_DATA_WIDTH-1:0]   trap_cause_i,
    input wire [`INST_ADDR_WIDTH-1:0]   trap_epc_i,
    input wire [`REGS_DATA_WIDTH-1:0]   trap_tval_i,

    // from csr_reg
    input wire [`REGS_DATA_WIDTH-1:0] csr_clint_data_i,
    input wire [`REGS_DATA_WIDTH-1:0] csr_clint_mtvec,
    input wire [`REGS_DATA_WIDTH-1:0] csr_clint_mepc,
    input wire [`REGS_DATA_WIDTH-1:0] csr_clint_mstatus,

    input wire global_int_en_i,

    // to ctrl
    output wire                       clint_stall_o,

    // to csr_reg
    output wire                       clint_csr_we_o,
    output wire [`CSR_ADDR_WIDTH-1:0] clint_csr_waddr_o,
    output wire [`CSR_ADDR_WIDTH-1:0] clint_csr_raddr_o,
    output wire [`REGS_DATA_WIDTH-1:0] clint_csr_data_o,

    // to ex
    output wire [`INST_ADDR_WIDTH-1:0] clint_ex_int_addr_o,
    output wire                        interrupt_o
);

    localparam [2:0] S_IDLE        = 3'd0;
    localparam [2:0] S_TRAP_MEPC   = 3'd1;
    localparam [2:0] S_TRAP_STATUS = 3'd2;
    localparam [2:0] S_TRAP_CAUSE  = 3'd3;
    localparam [2:0] S_TRAP_TVAL   = 3'd4;
    localparam [2:0] S_MRET_STATUS = 3'd5;

    wire sys_op_ecall  = sys_op_info_i[`OP_SYS_ECALL] & sys_op_i;
    wire sys_op_ebreak = sys_op_info_i[`OP_SYS_EBREAK] & sys_op_i;
    wire sys_op_mret   = sys_op_info_i[`OP_SYS_MRET] & sys_op_i;

    wire sys_trap_req = sys_op_ecall | sys_op_ebreak;
    wire trap_req = trap_valid_i | sys_trap_req;

    reg [2:0] csr_state_q;
    reg [`INST_ADDR_WIDTH-1:0] epc_q;
    reg [`REGS_DATA_WIDTH-1:0] cause_q;
    reg [`REGS_DATA_WIDTH-1:0] tval_q;

    reg                        we_q;
    reg [`CSR_ADDR_WIDTH-1:0]  waddr_q;
    reg [`CSR_ADDR_WIDTH-1:0]  raddr_q;
    reg [`REGS_DATA_WIDTH-1:0] data_q;
    reg                        int_assert_q;
    reg [`INST_ADDR_WIDTH-1:0] int_addr_q;

    wire take_trap = (csr_state_q == S_IDLE) & trap_req;
    wire take_mret = (csr_state_q == S_IDLE) & !trap_req & sys_op_mret;

    wire [`REGS_DATA_WIDTH-1:0] requested_cause =
        trap_valid_i ? trap_cause_i :
        sys_op_ebreak ? `TRAP_CAUSE_BREAKPOINT :
        `TRAP_CAUSE_MACHINE_ECALL;
    wire [`INST_ADDR_WIDTH-1:0] requested_epc =
        trap_valid_i ? trap_epc_i : instr_addr_i;
    wire [`REGS_DATA_WIDTH-1:0] requested_tval =
        trap_valid_i ? trap_tval_i : `REGS_DATA_WIDTH'b0;

    function automatic [`REGS_DATA_WIDTH-1:0] trap_mstatus(
        input [`REGS_DATA_WIDTH-1:0] mstatus_i
    );
        reg [`REGS_DATA_WIDTH-1:0] value;
        begin
            value = mstatus_i;
            value[7] = mstatus_i[3];    // MPIE <= MIE
            value[3] = 1'b0;            // MIE <= 0
            value[12:11] = 2'b11;       // MPP <= M
            trap_mstatus = value;
        end
    endfunction

    function automatic [`REGS_DATA_WIDTH-1:0] mret_mstatus(
        input [`REGS_DATA_WIDTH-1:0] mstatus_i
    );
        reg [`REGS_DATA_WIDTH-1:0] value;
        begin
            value = mstatus_i;
            value[3] = mstatus_i[7];    // MIE <= MPIE
            value[7] = 1'b1;            // MPIE <= 1
            value[12:11] = 2'b11;       // no lower privilege modes implemented
            mret_mstatus = value;
        end
    endfunction

    assign clint_stall_o = (csr_state_q != S_IDLE) | trap_req | sys_op_mret;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_state_q <= S_IDLE;
            epc_q       <= '0;
            cause_q     <= '0;
            tval_q      <= '0;
            we_q        <= 1'b0;
            waddr_q     <= '0;
            raddr_q     <= '0;
            data_q      <= '0;
            int_assert_q <= 1'b0;
            int_addr_q  <= '0;
        end else begin
            we_q         <= 1'b0;
            waddr_q      <= '0;
            raddr_q      <= '0;
            data_q       <= '0;
            int_assert_q <= 1'b0;
            int_addr_q   <= '0;

            if (take_trap) begin
                epc_q       <= requested_epc;
                cause_q     <= requested_cause;
                tval_q      <= requested_tval;
                csr_state_q <= S_TRAP_MEPC;
            end else if (take_mret) begin
                csr_state_q <= S_MRET_STATUS;
            end else begin
                case (csr_state_q)
                    S_TRAP_MEPC: begin
                        we_q        <= 1'b1;
                        waddr_q     <= `CSR_MEPC;
                        data_q      <= {epc_q[`INST_ADDR_WIDTH-1:2], 2'b00};
                        csr_state_q <= S_TRAP_STATUS;
                    end

                    S_TRAP_STATUS: begin
                        we_q        <= 1'b1;
                        waddr_q     <= `CSR_MSTATUS;
                        data_q      <= trap_mstatus(csr_clint_mstatus);
                        csr_state_q <= S_TRAP_CAUSE;
                    end

                    S_TRAP_CAUSE: begin
                        we_q        <= 1'b1;
                        waddr_q     <= `CSR_MCAUSE;
                        data_q      <= cause_q;
                        csr_state_q <= S_TRAP_TVAL;
                    end

                    S_TRAP_TVAL: begin
                        we_q         <= 1'b1;
                        waddr_q      <= `CSR_MTVAL;
                        data_q       <= tval_q;
                        int_assert_q <= 1'b1;
                        int_addr_q   <= {csr_clint_mtvec[`INST_ADDR_WIDTH-1:2], 2'b00};
                        csr_state_q  <= S_IDLE;
                    end

                    S_MRET_STATUS: begin
                        we_q         <= 1'b1;
                        waddr_q      <= `CSR_MSTATUS;
                        data_q       <= mret_mstatus(csr_clint_mstatus);
                        int_assert_q <= 1'b1;
                        int_addr_q   <= {csr_clint_mepc[`INST_ADDR_WIDTH-1:2], 2'b00};
                        csr_state_q  <= S_IDLE;
                    end

                    default: begin
                        csr_state_q <= S_IDLE;
                    end
                endcase
            end
        end
    end

    assign clint_csr_we_o       = we_q;
    assign clint_csr_waddr_o    = waddr_q;
    assign clint_csr_raddr_o    = raddr_q;
    assign clint_csr_data_o     = data_q;
    assign interrupt_o          = int_assert_q;
    assign clint_ex_int_addr_o  = int_addr_q;

endmodule
