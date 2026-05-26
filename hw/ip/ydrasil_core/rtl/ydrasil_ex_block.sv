`include "define_decode.svh"
`include "define_mem_reg.svh"

module ydrasil_ex_block #(
	parameter int DATA_WIDTH = 32
)(
	input  wire                            clk,
    input  wire                            rst_n,
	input  wire                            flush_ex_i,

    input  wire [DATA_WIDTH-1:0]           bt_a_operand_i,
    input  wire [DATA_WIDTH-1:0]           bt_b_operand_i,
	
    input  wire [DATA_WIDTH-1:0]           operand_a_i,
	input  wire [DATA_WIDTH-1:0]           operand_b_i,
	input  wire [`OPERATOR_WIDTH-1:0]      operator_i,
	input  wire [`OPERATOR_TYPE_WIDTH-1:0] operator_type_i,
    input  wire [ 4:0]                     id_rf_waddr_rd_i,
    input  wire                            id_alu_rf_wen_rd_i,
	input  wire                            id_ex_rs2_rd_forward_i,
	input  wire                            id_ex_rs1_rd_forward_i,
	input  wire 						  id_ex_bt_rs1_rd_forward_i,
	input  wire 							interrupt_i,
	input wire  [`INST_ADDR_WIDTH-1:0]      clint_ex_int_addr_i,
	input wire [`REGS_ADDR_WIDTH-1:0]      id_ex_rs2_raddr_i,
	input wire [`REGS_ADDR_WIDTH-1:0]      id_ex_rs1_raddr_i,
	input wire [`REGS_DATA_WIDTH-1:0]     	wb_ex_pending_wdata_rd_ff_i,
 	input wire [`REGS_ADDR_WIDTH-1:0]		wb_ex_pending_waddr_rd_ff_i,
 	input wire                       		wb_ex_pending_ff_i,
	input wire [`OPSEL_INFO_WIDTH-1:0]		sel_rs_i,
	input  wire                            id_ex_valid_i,
	input  wire                            id_ex_illegal_instr_i,
	input  wire [DATA_WIDTH-1:0]           id_ex_instr_i,
	input  wire [DATA_WIDTH-1:0]           id_instr_addr_i,

	input  wire [`CSR_ADDR_WIDTH-1:0] 	   id_ex_csr_waddr_i,
	input  wire [`OP_CSR_INFO_WIDTH-1:0]   id_op_csr_info_i,
	input  wire [DATA_WIDTH-1:0]           csr_ex_rdata_i,

	output wire 						   ex_csr_wen_o,
	output wire [DATA_WIDTH-1:0]           ex_csr_wdata_o,
	output wire [`CSR_ADDR_WIDTH-1:0] 	   ex_csr_waddr_o,
	
	output wire                            ex_branch_jump_o,      // to CTRL
	output wire [DATA_WIDTH-1:0]           ex_branch_target_o, // to CTRL
    output wire [`BUS_ADDR_WIDTH-1:0]      ex_lsu_mem_addr_o,      // to EX 

	output wire [DATA_WIDTH-1:0]           ex_lsu_result_o,        // to EX

	    output wire [`REGS_DATA_WIDTH-1:0]     alu_result_o,
	    output wire                            alu_rf_wen_rd_o,
	    output wire [`REGS_ADDR_WIDTH-1:0]     alu_rf_waddr_rd_o,
		output wire                            ex_mul_stall_o,
		output wire                            ex_trap_valid_o,
		output wire [DATA_WIDTH-1:0]           ex_trap_cause_o,
		output wire [DATA_WIDTH-1:0]           ex_trap_epc_o,
		output wire [DATA_WIDTH-1:0]           ex_trap_tval_o
	);

	// 分支目标地址：EX 内部单独加法器计算 PC + imm_b
	wire [31:0] bt_alu_result;
	wire [`REGS_DATA_WIDTH-1:0]     alu_result;
	wire                            alu_rf_wen_rd;
	wire [`REGS_ADDR_WIDTH-1:0]     alu_rf_waddr_rd;
	wire                            op_m_unit;
	wire                            op_mul;
	wire                            op_div;
	wire                            mul_start;
	wire                            mul_busy;
	wire                            mul_done;
	wire [`DOUBLE_REGS_WIDTH-1:0]   mul_result;
	wire [`REGS_DATA_WIDTH-1:0]     mul_wb_result;
	wire                            div_start;
	wire                            div_busy;
	wire                            div_done;
	wire [`REGS_DATA_WIDTH-1:0]     div_result;
	wire                            m_done;
	wire [`REGS_DATA_WIDTH-1:0]     m_wb_result;
	wire                            m_rf_wen_rd;
	wire                            normal_alu_rf_wen_rd;
	wire                            ex_rf_wen_rd;

	reg [`REGS_DATA_WIDTH-1:0]     alu_result_ff;
	reg                            alu_rf_wen_rd_ff;
	reg [`REGS_ADDR_WIDTH-1:0]     alu_rf_waddr_rd_ff;

	wire ex_branch_jump;

	wire [31:0] operand_a;
	wire [31:0] operand_b;

	wire [31:0] bt_a_operand;
	wire [31:0] bt_b_operand;

	wire op_a_sel_rs1;
	wire bt_a_sel_rs1;
	wire op_b_sel_rs2;

	assign op_a_sel_rs1 = sel_rs_i[`ASELRS];
	assign bt_a_sel_rs1 = sel_rs_i[`BTASELRS];
	assign op_b_sel_rs2 = sel_rs_i[`BSELRS];

	wire wb_ex_bt_rs1_rd_forward;
	wire wb_ex_rs1_rd_forward;
	wire wb_ex_rs2_rd_forward;

	assign wb_ex_bt_rs1_rd_forward = bt_a_sel_rs1 & wb_ex_pending_ff_i & (id_ex_rs1_raddr_i == wb_ex_pending_waddr_rd_ff_i) && (id_ex_rs1_raddr_i!= '0);
	assign wb_ex_rs1_rd_forward = op_a_sel_rs1 & wb_ex_pending_ff_i & (id_ex_rs1_raddr_i == wb_ex_pending_waddr_rd_ff_i)&& (id_ex_rs1_raddr_i!= '0);
	assign wb_ex_rs2_rd_forward = op_b_sel_rs2 & wb_ex_pending_ff_i & (id_ex_rs2_raddr_i == wb_ex_pending_waddr_rd_ff_i)&& (id_ex_rs2_raddr_i!= '0);

	assign bt_a_operand = id_ex_bt_rs1_rd_forward_i? alu_result_ff :wb_ex_bt_rs1_rd_forward ?wb_ex_pending_wdata_rd_ff_i:bt_a_operand_i;
	assign bt_b_operand = bt_b_operand_i;

    assign bt_alu_result = bt_a_operand + bt_b_operand;
	assign ex_lsu_mem_addr_o = alu_result;
	wire [31:0] branch_target;
	wire        branch_target_misaligned;
	wire        ex_local_trap;
	assign branch_target = bt_a_sel_rs1 ? {bt_alu_result[31:1], 1'b0} : bt_alu_result;
	assign branch_target_misaligned = ex_branch_jump & branch_target[1];
	assign ex_local_trap = id_ex_valid_i & (id_ex_illegal_instr_i | branch_target_misaligned);
    assign ex_branch_target_o = interrupt_i ? clint_ex_int_addr_i : branch_target;

	// 内部例化 ALU，EX 直接透传控制和操作数

	assign operand_a = id_ex_rs1_rd_forward_i ? alu_result_ff :wb_ex_rs1_rd_forward?wb_ex_pending_wdata_rd_ff_i: operand_a_i;
	assign operand_b = id_ex_rs2_rd_forward_i ? alu_result_ff :wb_ex_rs2_rd_forward?wb_ex_pending_wdata_rd_ff_i: operand_b_i;

	assign ex_lsu_result_o = alu_result_ff ;

	assign ex_branch_jump_o = (id_ex_valid_i & ex_branch_jump & !branch_target_misaligned & !id_ex_illegal_instr_i) | interrupt_i;
	assign op_m_unit = id_ex_valid_i & operator_type_i[`OPERATOR_TYPE_MUL];
	assign op_mul = op_m_unit &
					(operator_i[`OP_MUL_MUL] | operator_i[`OP_MUL_MULH] |
					 operator_i[`OP_MUL_MULHSU] | operator_i[`OP_MUL_MULHU]);
	assign op_div = op_m_unit &
					(operator_i[`OP_MUL_DIV] | operator_i[`OP_MUL_DIVU] |
					 operator_i[`OP_MUL_REM] | operator_i[`OP_MUL_REMU]);
	assign mul_start = op_mul & !mul_busy & !mul_done & !interrupt_i & !ex_local_trap;
	assign div_start = op_div & !div_busy & !div_done & !interrupt_i & !ex_local_trap;
	assign m_done = (op_mul & mul_done) | (op_div & div_done);
	assign ex_mul_stall_o = op_m_unit & !m_done;
	assign mul_wb_result = operator_i[`OP_MUL_MUL] ? mul_result[31:0] : mul_result[63:32];
	assign m_wb_result = op_div ? div_result : mul_wb_result;
	assign m_rf_wen_rd = m_done & id_alu_rf_wen_rd_i & !interrupt_i & !ex_local_trap;
	assign normal_alu_rf_wen_rd = alu_rf_wen_rd & !op_m_unit & !ex_local_trap;

	ydrasil_alu #(
		.DATAWIDTH(DATA_WIDTH)
	) u_ydrasil_alu (
		// .rst_n            (rst_n),
		// .req_alu_i        (ex_valid_i),
		.operand_a_i      (operand_a),
		.operand_b_i      (operand_b),
		.operator_i       (operator_i),
		.operator_type_i  (operator_type_i),
		.interrupt_i	   (interrupt_i),
		.id_rf_waddr_rd_i (id_rf_waddr_rd_i),
		.id_alu_rf_wen_rd_i   (id_alu_rf_wen_rd_i),
		.comp_result_o    (ex_branch_jump),
		.alu_result_o     (alu_result),
		.alu_rf_wen_rd_o  (alu_rf_wen_rd),
		.alu_rf_waddr_rd_o (alu_rf_waddr_rd)
	);

	ydrasil_mul u_ydrasil_mul (
		.clk             (clk),
		.rst_n           (rst_n),
		.flush_i         (flush_ex_i | interrupt_i),
		.start_i         (mul_start),
		.operand_a_i     (operand_a),
		.operand_b_i     (operand_b),
		.operator_i      (operator_i),
		.busy_o          (mul_busy),
		.done_o          (mul_done),
		.result_o        (mul_result)
	);

	ydrasil_div u_ydrasil_div (
		.clk             (clk),
		.rst_n           (rst_n),
		.flush_i         (flush_ex_i | interrupt_i),
		.start_i         (div_start),
		.operand_a_i     (operand_a),
		.operand_b_i     (operand_b),
		.operator_i      (operator_i),
		.busy_o          (div_busy),
		.done_o          (div_done),
		.result_o        (div_result)
	);

	wire [31:0] alu_csr_result;
	wire csr_wen;


	assign alu_result_o = alu_result_ff;
	assign alu_rf_wen_rd_o = alu_rf_wen_rd_ff;
	assign alu_rf_waddr_rd_o = alu_rf_waddr_rd_ff;

	//csr

		wire op_csr = id_ex_valid_i & operator_type_i[`OPERATOR_TYPE_CSR] ;

		wire csr_csrrw = op_csr & id_op_csr_info_i[`OP_CSR_CSRRW];
		wire csr_csrrs = op_csr & id_op_csr_info_i[`OP_CSR_CSRRS];
		wire csr_csrrc = op_csr & id_op_csr_info_i[`OP_CSR_CSRRC];

		wire [31:0]csr_reg_wdata ;
		wire [31:0]csr_wdata ;
		wire csr_source_zero;
		wire csr_write_side_effect;
		wire csr_rf_wen;

	reg [`REGS_DATA_WIDTH-1:0] ex_csr_wdata_o_ff;
	reg 						ex_csr_wen_o_ff;
	reg [`CSR_ADDR_WIDTH-1:0] ex_csr_waddr_o_ff;


	assign csr_reg_wdata = interrupt_i ? '0: csr_ex_rdata_i;
	assign csr_wdata = interrupt_i ? '0:
							({`REGS_DATA_WIDTH{csr_csrrw}} & operand_a) |
                          	({`REGS_DATA_WIDTH{csr_csrrs}} & (operand_a | csr_ex_rdata_i)) |
                          	({`REGS_DATA_WIDTH{csr_csrrc}} & (csr_ex_rdata_i & (~operand_a)));
	assign csr_source_zero = op_a_sel_rs1 ? (id_ex_rs1_raddr_i == '0) : (operand_a[4:0] == 5'b0);
	assign csr_write_side_effect = csr_csrrw | ((csr_csrrs | csr_csrrc) & !csr_source_zero);
	assign csr_wen = op_csr & csr_write_side_effect & !ex_local_trap & !interrupt_i;
	assign csr_rf_wen = op_csr & id_alu_rf_wen_rd_i & !ex_local_trap & !interrupt_i;
	assign ex_rf_wen_rd = m_rf_wen_rd | normal_alu_rf_wen_rd | csr_rf_wen;
	
	always_ff @(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			alu_result_ff <= '0;
			alu_rf_wen_rd_ff <= 1'b0;
			alu_rf_waddr_rd_ff <= '0;
			ex_csr_wdata_o_ff <= '0;
			ex_csr_wen_o_ff <= 1'b0;
			ex_csr_waddr_o_ff <= '0;
		end 
		else if(flush_ex_i) begin
			alu_result_ff <= '0;
			alu_rf_wen_rd_ff <= 1'b0;
			alu_rf_waddr_rd_ff <= '0;
			ex_csr_wdata_o_ff <= '0;
			ex_csr_wen_o_ff <= 1'b0;
			ex_csr_waddr_o_ff <= '0;
			end
			else begin
				alu_result_ff <= alu_csr_result;
				alu_rf_wen_rd_ff <= ex_rf_wen_rd;
				alu_rf_waddr_rd_ff <= m_rf_wen_rd ? id_rf_waddr_rd_i : alu_rf_waddr_rd;
				ex_csr_wdata_o_ff <= csr_wdata;
				ex_csr_wen_o_ff <= csr_wen;
				ex_csr_waddr_o_ff <= id_ex_csr_waddr_i;
		end
	end
	
	assign ex_csr_wdata_o = ex_csr_wdata_o_ff;
	assign ex_csr_wen_o = ex_csr_wen_o_ff;
	assign ex_csr_waddr_o = ex_csr_waddr_o_ff;
	assign alu_csr_result = ({32{m_rf_wen_rd}} & m_wb_result) |
							({32{csr_rf_wen}} & csr_reg_wdata )|
							({32{normal_alu_rf_wen_rd} }& alu_result) ;

	assign ex_trap_valid_o = ex_local_trap;
	assign ex_trap_cause_o = id_ex_illegal_instr_i ? `TRAP_CAUSE_ILLEGAL_INSN :
	                         `TRAP_CAUSE_MISALIGNED_FETCH;
	assign ex_trap_epc_o   = id_instr_addr_i;
	assign ex_trap_tval_o  = id_ex_illegal_instr_i ? id_ex_instr_i : branch_target;




endmodule
