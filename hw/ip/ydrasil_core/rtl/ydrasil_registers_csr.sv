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
`include "define_rv32i_ins.svh"

module ydrasil_registers_csr (

    input wire clk,
    input wire rst_n,

    // form ex
    input wire                          ex_csr_wen_i,
    input wire [`CSR_ADDR_WIDTH-1:0]    id_csr_raddr_i,
    input wire [`CSR_ADDR_WIDTH-1:0]    ex_csr_waddr_i,
    input wire [`REGS_DATA_WIDTH-1:0]   ex_csr_data_i,

    // from clint
    input wire                          clint_csr_we_i,
    input wire [`CSR_ADDR_WIDTH-1:0]    clint_csr_raddr_i,
    input wire [`CSR_ADDR_WIDTH-1:0]    clint_csr_waddr_i,
    input wire [`REGS_DATA_WIDTH-1:0]   clint_csr_data_i,

    output wire global_int_en_o,

    // to clint
    output wire [`REGS_DATA_WIDTH-1:0] csr_clint_data_o,
    output wire [`REGS_DATA_WIDTH-1:0] csr_clint_mtvec,
    output wire [`REGS_DATA_WIDTH-1:0] csr_clint_mepc,
    output wire [`REGS_DATA_WIDTH-1:0] csr_clint_mstatus,

    // to ex
    output wire [`REGS_DATA_WIDTH-1:0] csr_ex_data_o

);

    localparam [`REGS_DATA_WIDTH-1:0] MISA_RV32IM =
        32'h4000_0000 | (32'h1 << 8) | (32'h1 << 12);

    reg [`DOUBLE_REGS_WIDTH-1:0] cycle;
    reg [`DOUBLE_REGS_WIDTH-1:0] instret;
    reg [`REGS_DATA_WIDTH-1:0] mtvec;
    reg [`REGS_DATA_WIDTH-1:0] mcause;
    reg [`REGS_DATA_WIDTH-1:0] mepc;
    reg [`REGS_DATA_WIDTH-1:0] mtval;
    reg [`REGS_DATA_WIDTH-1:0] mie;
    reg [`REGS_DATA_WIDTH-1:0] mstatus;
    reg [`REGS_DATA_WIDTH-1:0] mscratch;
    reg [`REGS_DATA_WIDTH-1:0] pmpcfg0;
    reg [`REGS_DATA_WIDTH-1:0] pmpaddr0;

    function automatic [`REGS_DATA_WIDTH-1:0] mstatus_warl(
        input [`REGS_DATA_WIDTH-1:0] value_i
    );
        reg [`REGS_DATA_WIDTH-1:0] value;
        begin
            value = value_i & 32'h0000_1888; // MIE, MPIE, MPP only
            value[12:11] = 2'b11;            // only M-mode is implemented
            mstatus_warl = value;
        end
    endfunction

    function automatic csr_is_ro_zero(input [`CSR_ADDR_WIDTH-1:0] addr);
        begin
            csr_is_ro_zero =
                (addr == `CSR_MVENDORID) ||
                (addr == `CSR_MARCHID) ||
                (addr == `CSR_MIMPID) ||
                (addr == `CSR_MHARTID) ||
                (addr == `CSR_MEDELEG) ||
                (addr == `CSR_MIDELEG) ||
                (addr == `CSR_MIP) ||
                (addr == `CSR_MCOUNTEREN) ||
                (addr == `CSR_MCOUNTINHIBIT) ||
                (addr == `CSR_MSTATUSH) ||
                (addr == `CSR_SATP);
        end
    endfunction

    function automatic csr_is_writable_implemented(input [`CSR_ADDR_WIDTH-1:0] addr);
        begin
            case (addr)
                `CSR_CYCLE,
                `CSR_TIME,
                `CSR_MCYCLE,
                `CSR_CYCLEH,
                `CSR_TIMEH,
                `CSR_MCYCLEH,
                `CSR_INSTRET,
                `CSR_MINSTRET,
                `CSR_INSTRETH,
                `CSR_MINSTRETH,
                `CSR_MTVEC,
                `CSR_MCAUSE,
                `CSR_MEPC,
                `CSR_MTVAL,
                `CSR_MIE,
                `CSR_MSTATUS,
                `CSR_MSCRATCH,
                `CSR_PMPCFG0,
                `CSR_PMPADDR0: csr_is_writable_implemented = 1'b1;
                default:       csr_is_writable_implemented = 1'b0;
            endcase
        end
    endfunction

    function automatic [`REGS_DATA_WIDTH-1:0] csr_read(
        input [`CSR_ADDR_WIDTH-1:0] addr
    );
        begin
            case (addr)
                `CSR_CYCLE,
                `CSR_TIME,
                `CSR_MCYCLE:    csr_read = cycle[31:0];
                `CSR_CYCLEH,
                `CSR_TIMEH,
                `CSR_MCYCLEH:   csr_read = cycle[63:32];
                `CSR_INSTRET,
                `CSR_MINSTRET:  csr_read = (instret == {`DOUBLE_REGS_WIDTH{1'b1}}) ? '0 : instret[31:0];
                `CSR_INSTRETH,
                `CSR_MINSTRETH: csr_read = (instret == {`DOUBLE_REGS_WIDTH{1'b1}}) ? '0 : instret[63:32];
                `CSR_MISA:      csr_read = MISA_RV32IM;
                `CSR_MTVEC:     csr_read = mtvec;
                `CSR_MCAUSE:    csr_read = mcause;
                `CSR_MEPC:      csr_read = mepc;
                `CSR_MTVAL:     csr_read = mtval;
                `CSR_MIE:       csr_read = mie;
                `CSR_MSTATUS:   csr_read = mstatus;
                `CSR_MSCRATCH:  csr_read = mscratch;
                `CSR_PMPCFG0:   csr_read = pmpcfg0;
                `CSR_PMPADDR0:  csr_read = pmpaddr0;
                default:        csr_read = '0;
            endcase
        end
    endfunction

    wire [`CSR_ADDR_WIDTH-1:0] ex_addr = ex_csr_waddr_i[11:0];
    wire [`CSR_ADDR_WIDTH-1:0] clint_addr = clint_csr_waddr_i[11:0];
    wire write_en = ex_csr_wen_i | clint_csr_we_i;
    wire [`CSR_ADDR_WIDTH-1:0] write_addr = ex_csr_wen_i ? ex_addr : clint_addr;
    wire [`REGS_DATA_WIDTH-1:0] write_data_raw = ex_csr_wen_i ? ex_csr_data_i : clint_csr_data_i;

    wire [`REGS_DATA_WIDTH-1:0] write_data =
        (write_addr == `CSR_MSTATUS) ? mstatus_warl(write_data_raw) :
        (write_addr == `CSR_MISA) ? MISA_RV32IM :
        write_data_raw;
    wire write_instret_low =
        write_en && ((write_addr == `CSR_INSTRET) || (write_addr == `CSR_MINSTRET));
    wire write_instret_high =
        write_en && ((write_addr == `CSR_INSTRETH) || (write_addr == `CSR_MINSTRETH));

    assign global_int_en_o   = mstatus[3];
    assign csr_clint_mtvec   = mtvec;
    assign csr_clint_mepc    = mepc;
    assign csr_clint_mstatus = mstatus;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle    <= {`DOUBLE_REGS_WIDTH{1'b0}};
            instret  <= {`DOUBLE_REGS_WIDTH{1'b0}};
            mtvec    <= {`REGS_DATA_WIDTH{1'b0}};
            mcause   <= {`REGS_DATA_WIDTH{1'b0}};
            mepc     <= {`REGS_DATA_WIDTH{1'b0}};
            mtval    <= {`REGS_DATA_WIDTH{1'b0}};
            mie      <= {`REGS_DATA_WIDTH{1'b0}};
            mstatus  <= mstatus_warl({`REGS_DATA_WIDTH{1'b0}});
            mscratch <= {`REGS_DATA_WIDTH{1'b0}};
            pmpcfg0  <= {`REGS_DATA_WIDTH{1'b0}};
            pmpaddr0 <= {`REGS_DATA_WIDTH{1'b0}};
        end else begin
            cycle <= cycle + 1'b1;
            if (write_instret_low) begin
                instret[31:0] <= write_data;
            end else if (write_instret_high) begin
                instret[63:32] <= write_data;
            end else begin
                instret <= instret + 1'b1;
            end

            if (write_en) begin
                case (write_addr)
                    `CSR_CYCLE,
                    `CSR_TIME,
                    `CSR_MCYCLE: begin
                        cycle[31:0] <= write_data;
                    end

                    `CSR_CYCLEH,
                    `CSR_TIMEH,
                    `CSR_MCYCLEH: begin
                        cycle[63:32] <= write_data;
                    end

                    `CSR_INSTRET,
                    `CSR_MINSTRET: begin
                        instret[31:0] <= write_data;
                    end

                    `CSR_INSTRETH,
                    `CSR_MINSTRETH: begin
                        instret[63:32] <= write_data;
                    end

                    `CSR_MTVEC:    mtvec    <= write_data;
                    `CSR_MCAUSE:   mcause   <= write_data;
                    `CSR_MEPC:     mepc     <= {write_data[`REGS_DATA_WIDTH-1:1], 1'b0};
                    `CSR_MTVAL:    mtval    <= write_data;
                    `CSR_MIE:      mie      <= write_data;
                    `CSR_MSTATUS:  mstatus  <= write_data;
                    `CSR_MSCRATCH: mscratch <= write_data;
                    `CSR_PMPCFG0:  pmpcfg0  <= write_data;
                    `CSR_PMPADDR0: pmpaddr0 <= write_data;
                    default: begin
                    end
                endcase
            end
        end
    end

    wire [`REGS_DATA_WIDTH-1:0] csr_ex_read_data = csr_read(id_csr_raddr_i[11:0]);
    wire [`REGS_DATA_WIDTH-1:0] csr_clint_read_data = csr_read(clint_csr_raddr_i[11:0]);

    assign csr_ex_data_o =
        (ex_csr_wen_i && (ex_addr == id_csr_raddr_i[11:0]) && csr_is_writable_implemented(ex_addr)) ? write_data :
        csr_ex_read_data;

    assign csr_clint_data_o =
        (clint_csr_we_i && (clint_addr == clint_csr_raddr_i[11:0]) && csr_is_writable_implemented(clint_addr)) ? write_data :
        csr_clint_read_data;

endmodule
