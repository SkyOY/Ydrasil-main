`include "define_rv32i_ins.svh"

module ydrasil_if_stage #(
)(
	input  wire        clk,
	input  wire        rst_n,

	// 流水线控制信号
	input  wire        stall_if_i,
	input  wire        stall_pc_i,
	input  wire        flush_if_i,

	// 后级跳转
	input  wire        branch_jump_i,
	input  wire [31:0] branch_target_i,

	// 指令存储器接口
	output wire [31:0] if_mem_addr_o,
	input  wire [31:0] if_mem_rdata_i,

	// IF/ID 流水寄存器输出
	output wire [31:0] if_id_pc_o,

	output wire [31:0] if_id_instr_o,
	output wire        if_id_valid_o

);

	// RV32I 标准 NOP 指令：addi x0, x0, 0
	// 当前 PC、下一拍 PC、以及 PC+4

	wire [31:0] pc_n;
	wire [31:0] pc_plus4;
	wire [31:0] if_id_instr_n;
	wire [31:0] pc_now;
	reg [31:0] pc_ff;
	reg [31:0] if_id_pc_ff;
	reg [31:0] if_id_instr_ff;
	reg        if_id_valid_ff;
	reg [31:0] fetch_pc_ff;
	reg        fetch_valid_ff;
	reg [31:0] skid_pc_ff;
	reg [31:0] skid_instr_ff;
	reg        skid_valid_ff;

	// 默认顺序取指地址：PC + 4
	assign pc_plus4   = pc_ff + 32'd4;
	// 若发生重定向则跳转到目标 PC，否则顺序执行
	assign pc_n       = branch_jump_i ? branch_target_i : stall_pc_i ? pc_ff : pc_plus4;

	assign if_mem_addr_o = pc_ff;

	assign if_id_pc_o    = if_id_pc_ff;
	assign if_id_instr_o = if_id_instr_ff;
	assign if_id_valid_o = if_id_valid_ff;
	assign pc_now =  pc_ff;
	assign if_id_instr_n = flush_if_i ? `RV32I_INS_NOP : if_mem_rdata_i;



	// IF 级 PC 寄存器：复位置初值，非停顿时更新
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			pc_ff <= `RESET_INS;
		end else begin
			pc_ff <= pc_n;
		end
	end




	// IF/ID 流水寄存器：支持复位、冲刷和停顿
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			if_id_pc_ff    <= `RESET_INS;
			if_id_instr_ff <= `RV32I_INS_NOP;
			if_id_valid_ff <= 1'b0;
			fetch_pc_ff    <= `RESET_INS;
			fetch_valid_ff <= 1'b0;
			skid_pc_ff     <= `RESET_INS;
			skid_instr_ff  <= `RV32I_INS_NOP;
			skid_valid_ff  <= 1'b0;
		end 
		else begin
			if(stall_if_i) begin
				if (!skid_valid_ff) begin
					skid_pc_ff    <= fetch_pc_ff;
					skid_instr_ff <= if_id_instr_n;
					skid_valid_ff <= fetch_valid_ff & !flush_if_i;
				end
			end else if (skid_valid_ff) begin
				if_id_pc_ff    <= skid_pc_ff;
				if_id_instr_ff <= flush_if_i ? `RV32I_INS_NOP : skid_instr_ff;
				if_id_valid_ff <= skid_valid_ff & !flush_if_i;
				fetch_pc_ff    <= pc_now;
				fetch_valid_ff <= !branch_jump_i;
				skid_valid_ff  <= 1'b0;
			end else begin
				if_id_pc_ff    <= fetch_pc_ff;
				if_id_instr_ff <= if_id_instr_n;
				if_id_valid_ff <= fetch_valid_ff & !flush_if_i;
				fetch_pc_ff    <= pc_now;
				fetch_valid_ff <= !branch_jump_i;
			end
		end
	end

endmodule
