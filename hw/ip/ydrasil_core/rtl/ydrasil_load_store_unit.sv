`include "define_decode.svh"
`include "define_mem_reg.svh"

// 地址生成单元 - 处理内存访问和相关寄存器操作
module ydrasil_load_store_unit (
    input wire clk,  // 时钟输入
    input wire rst_n,

    input wire [`BUS_ADDR_WIDTH-1:0]       ex_lsu_mem_addr_i,
    input wire [ 4:0]                      id_rd_waddr_i,
    input wire [`OP_LSU_INFO_WIDTH-1:0]    operator_lsu_i,
    input wire [1:0]                       operator_lsu_type_i,
    input wire [`REGS_DATA_WIDTH-1:0]      id_lsu_rs2_data_i, // 存储操作的源寄存器数据
    input wire [`REGS_DATA_WIDTH-1:0]      ex_lsu_rd_data_i, // 存储操作的源寄存器数据
    input wire                             id_lsu_rs2_rd_forward_i,
    
    // 内存接口
    input wire [`BUS_DATA_WIDTH-1:0]       lsu_mem_rdata_i,
    output wire [`BUS_DATA_WIDTH-1:0]      lsu_mem_wdata_o,
    output wire [`BUS_ADDR_WIDTH-1:0]      lsu_mem_addr_o,
    output wire                            lsu_mem_wen_o,
    output wire                            lsu_mem_req_o,
    output wire [                3:0]      lsu_mem_wmask_o,  // 字节写入掩码，4位分别对应4个字节

	output wire                           	lsu_ctrl_stall_o,       // LSU 可能会因为等待内存响应而请求stall
    output wire                           	lsu_ctrl_stall_wb_o,    // LSU 可能会因为异常等原因
    output wire                            lsu_ctrl_busy_o,
    output wire [`REGS_ADDR_WIDTH-1:0]    	lsu_ctrl_waddr_rd_o,
    output wire [`REGS_ADDR_WIDTH-1:0]    	lsu_ctrl_waddr_rd_wb_o,


    // 寄存器写回接口
    output wire [`REGS_DATA_WIDTH-1:0]     lsu_wb_result_o,
    output wire                            lsu_rf_rd_wen_o,
    output wire [`REGS_ADDR_WIDTH-1:0]     lsu_rf_rd_waddr_o
);
    localparam [1:0] S_IDLE         = 2'd0;
    localparam [1:0] S_LOAD_FIRST   = 2'd1;
    localparam [1:0] S_LOAD_SECOND  = 2'd2;
    localparam [1:0] S_STORE_SECOND = 2'd3;

    reg [1:0] state_q;
    reg [`BUS_ADDR_WIDTH-1:0] addr_q;
    reg [`REGS_DATA_WIDTH-1:0] store_data_q;
    reg [`REGS_DATA_WIDTH-1:0] first_word_q;
    reg [`OP_LSU_INFO_WIDTH-1:0] operator_lsu_q;
    reg [`REGS_ADDR_WIDTH-1:0] rd_addr_q;
    reg [1:0] addr_index_q;
    reg load_cross_q;
    reg store_cross_q;
    reg [`REGS_DATA_WIDTH-1:0] result_q;
    reg result_valid_q;

    wire [`REGS_DATA_WIDTH-1:0] lsu_rs2_data;
    wire is_load;
    wire is_store;
    wire [1:0] mem_addr_index;
    wire [`BUS_ADDR_WIDTH-1:0] mem_addr;
    wire [`REGS_DATA_WIDTH-1:0] mem_rs2_data;
    wire request_valid;

    assign lsu_rs2_data  = id_lsu_rs2_rd_forward_i ? ex_lsu_rd_data_i : id_lsu_rs2_data_i;
    assign is_load       = operator_lsu_type_i[`OPERATOR_TYPE_LOAD - `OPERATOR_TYPE_LSU_BASE];
    assign is_store      = operator_lsu_type_i[`OPERATOR_TYPE_STORE - `OPERATOR_TYPE_LSU_BASE];
    assign mem_addr      = ex_lsu_mem_addr_i;
    assign mem_addr_index = mem_addr[1:0];
    assign mem_rs2_data  = lsu_rs2_data;
    assign request_valid = is_load | is_store;

    function automatic [2:0] access_size(input [`OP_LSU_INFO_WIDTH-1:0] op);
        begin
            if (op[`OP_LSU_LW] | op[`OP_LSU_SW]) begin
                access_size = 3'd4;
            end else if (op[`OP_LSU_LH] | op[`OP_LSU_LHU] | op[`OP_LSU_SH]) begin
                access_size = 3'd2;
            end else begin
                access_size = 3'd1;
            end
        end
    endfunction

    function automatic access_crosses_word(
        input [1:0] addr_index,
        input [`OP_LSU_INFO_WIDTH-1:0] op
    );
        begin
            access_crosses_word = ({1'b0, addr_index} + access_size(op)) > 3'd4;
        end
    endfunction

    function automatic [31:0] format_load_data(
        input [63:0] data,
        input [1:0] addr_index,
        input [`OP_LSU_INFO_WIDTH-1:0] op
    );
        reg [63:0] shifted_data;
        begin
            shifted_data = data >> ({3'b000, addr_index} << 3);
            if (op[`OP_LSU_LB]) begin
                format_load_data = {{24{shifted_data[7]}}, shifted_data[7:0]};
            end else if (op[`OP_LSU_LBU]) begin
                format_load_data = {24'b0, shifted_data[7:0]};
            end else if (op[`OP_LSU_LH]) begin
                format_load_data = {{16{shifted_data[15]}}, shifted_data[15:0]};
            end else if (op[`OP_LSU_LHU]) begin
                format_load_data = {16'b0, shifted_data[15:0]};
            end else begin
                format_load_data = shifted_data[31:0];
            end
        end
    endfunction

    function automatic [3:0] store_mask_for_word(
        input [1:0] addr_index,
        input [`OP_LSU_INFO_WIDTH-1:0] op,
        input high_word
    );
        integer lane;
        integer src_byte;
        integer start_lane;
        integer bytes;
        integer low_bytes;
        integer high_bytes;
        begin
            bytes = access_size(op);
            low_bytes = (bytes < (4 - addr_index)) ? bytes : (4 - addr_index);
            high_bytes = bytes - low_bytes;
            store_mask_for_word = 4'b0000;
            for (lane = 0; lane < 4; lane = lane + 1) begin
                start_lane = high_word ? 0 : addr_index;
                src_byte = high_word ? (low_bytes + lane) : (lane - addr_index);
                if (high_word) begin
                    if (lane < high_bytes) begin
                        store_mask_for_word[lane] = 1'b1;
                    end
                end else if ((lane >= start_lane) && (src_byte < low_bytes)) begin
                    store_mask_for_word[lane] = 1'b1;
                end
            end
        end
    endfunction

    function automatic [31:0] store_data_for_word(
        input [31:0] store_data,
        input [1:0] addr_index,
        input [`OP_LSU_INFO_WIDTH-1:0] op,
        input high_word
    );
        integer lane;
        integer src_byte;
        integer bytes;
        integer low_bytes;
        integer high_bytes;
        begin
            bytes = access_size(op);
            low_bytes = (bytes < (4 - addr_index)) ? bytes : (4 - addr_index);
            high_bytes = bytes - low_bytes;
            store_data_for_word = 32'b0;
            for (lane = 0; lane < 4; lane = lane + 1) begin
                if (high_word) begin
                    src_byte = low_bytes + lane;
                    if (lane < high_bytes) begin
                        store_data_for_word[(lane * 8) +: 8] = store_data[(src_byte * 8) +: 8];
                    end
                end else begin
                    src_byte = lane - addr_index;
                    if ((lane >= addr_index) && (src_byte < low_bytes)) begin
                        store_data_for_word[(lane * 8) +: 8] = store_data[(src_byte * 8) +: 8];
                    end
                end
            end
        end
    endfunction

    wire first_access_req = (state_q == S_IDLE) & request_valid;
    wire second_load_req  = (state_q == S_LOAD_FIRST) & load_cross_q;
    wire second_store_req = (state_q == S_STORE_SECOND);
    wire second_access    = second_load_req | second_store_req;
    wire [`BUS_ADDR_WIDTH-1:0] latched_next_addr = {addr_q[`BUS_ADDR_WIDTH-1:2] + 30'd1, 2'b00};
    wire [`OP_LSU_INFO_WIDTH-1:0] active_store_op =
        second_store_req ? operator_lsu_q : operator_lsu_i;
    wire [1:0] active_store_index = second_store_req ? addr_index_q : mem_addr_index;
    wire [31:0] active_store_data = second_store_req ? store_data_q : mem_rs2_data;

    assign lsu_mem_req_o   = first_access_req | second_access;
    assign lsu_mem_wen_o   = ((state_q == S_IDLE) & is_store) | second_store_req;
    assign lsu_mem_addr_o  = second_access ? latched_next_addr : mem_addr;
    assign lsu_mem_wmask_o = lsu_mem_wen_o ?
        store_mask_for_word(active_store_index, active_store_op, second_store_req) : 4'b0000;
    assign lsu_mem_wdata_o = lsu_mem_wen_o ?
        store_data_for_word(active_store_data, active_store_index, active_store_op, second_store_req) : 32'b0;

    assign lsu_ctrl_busy_o = (state_q != S_IDLE) | request_valid | result_valid_q;
    assign lsu_ctrl_stall_o = lsu_ctrl_busy_o;
    assign lsu_ctrl_stall_wb_o = result_valid_q;
    assign lsu_ctrl_waddr_rd_o = (state_q == S_IDLE) ? id_rd_waddr_i : rd_addr_q;
    assign lsu_ctrl_waddr_rd_wb_o = rd_addr_q;

    assign lsu_wb_result_o = result_q;
    assign lsu_rf_rd_wen_o = result_valid_q;
    assign lsu_rf_rd_waddr_o = result_valid_q ? rd_addr_q : '0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q       <= S_IDLE;
            addr_q        <= '0;
            store_data_q  <= '0;
            first_word_q  <= '0;
            operator_lsu_q <= '0;
            rd_addr_q     <= '0;
            addr_index_q  <= '0;
            load_cross_q  <= 1'b0;
            store_cross_q <= 1'b0;
            result_q      <= '0;
            result_valid_q <= 1'b0;
        end else begin
            result_valid_q <= 1'b0;

            case (state_q)
                S_IDLE: begin
                    if (request_valid) begin
                        addr_q         <= mem_addr;
                        store_data_q   <= mem_rs2_data;
                        operator_lsu_q <= operator_lsu_i;
                        rd_addr_q      <= id_rd_waddr_i;
                        addr_index_q   <= mem_addr_index;
                        load_cross_q   <= access_crosses_word(mem_addr_index, operator_lsu_i) & is_load;
                        store_cross_q  <= access_crosses_word(mem_addr_index, operator_lsu_i) & is_store;

                        if (is_load) begin
                            state_q <= S_LOAD_FIRST;
                        end else if (access_crosses_word(mem_addr_index, operator_lsu_i)) begin
                            state_q <= S_STORE_SECOND;
                        end
                    end
                end

                S_LOAD_FIRST: begin
                    if (load_cross_q) begin
                        first_word_q <= lsu_mem_rdata_i;
                        state_q      <= S_LOAD_SECOND;
                    end else begin
                        result_q       <= format_load_data({32'b0, lsu_mem_rdata_i}, addr_index_q, operator_lsu_q);
                        result_valid_q <= 1'b1;
                        state_q        <= S_IDLE;
                    end
                end

                S_LOAD_SECOND: begin
                    result_q       <= format_load_data({lsu_mem_rdata_i, first_word_q}, addr_index_q, operator_lsu_q);
                    result_valid_q <= 1'b1;
                    state_q        <= S_IDLE;
                end

                S_STORE_SECOND: begin
                    state_q <= S_IDLE;
                end

                default: begin
                    state_q <= S_IDLE;
                end
            endcase
        end
    end

endmodule
