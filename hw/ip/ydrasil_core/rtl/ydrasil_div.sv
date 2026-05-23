`include "define_decode.svh"
`include "define_mem_reg.svh"

module ydrasil_div (
    input  wire                            clk,
    input  wire                            rst_n,
    input  wire                            flush_i,

    input  wire                            start_i,
    input  wire [`REGS_DATA_WIDTH-1:0]     operand_a_i,
    input  wire [`REGS_DATA_WIDTH-1:0]     operand_b_i,
    input  wire [`OPERATOR_WIDTH-1:0]      operator_i,

    output wire                            busy_o,
    output wire                            done_o,
    output wire [`REGS_DATA_WIDTH-1:0]     result_o
);

    localparam [5:0] DIV_ITER_LAST = 6'd31;

    reg                            busy_q;
    reg                            done_q;
    reg [5:0]                      iter_q;
    reg [`REGS_DATA_WIDTH-1:0]     dividend_q;
    reg [`REGS_DATA_WIDTH-1:0]     divisor_q;
    reg [`REGS_DATA_WIDTH-1:0]     quotient_q;
    reg [`REGS_DATA_WIDTH:0]       remainder_q;
    reg                            quotient_neg_q;
    reg                            remainder_neg_q;
    reg                            rem_result_q;
    reg [`REGS_DATA_WIDTH-1:0]     result_q;

    wire op_div  = operator_i[`OP_MUL_DIV];
    wire op_rem  = operator_i[`OP_MUL_REM];
    wire op_remu = operator_i[`OP_MUL_REMU];

    wire signed_op = op_div | op_rem;
    wire rem_op    = op_rem | op_remu;

    wire dividend_neg = signed_op & operand_a_i[`REGS_DATA_WIDTH-1];
    wire divisor_neg  = signed_op & operand_b_i[`REGS_DATA_WIDTH-1];

    wire [`REGS_DATA_WIDTH-1:0] dividend_abs =
        dividend_neg ? (~operand_a_i + `REGS_DATA_WIDTH'd1) : operand_a_i;
    wire [`REGS_DATA_WIDTH-1:0] divisor_abs =
        divisor_neg ? (~operand_b_i + `REGS_DATA_WIDTH'd1) : operand_b_i;

    wire divisor_is_zero = (operand_b_i == `REGS_DATA_WIDTH'b0);
    wire signed_overflow = signed_op &
        (operand_a_i == {1'b1, {(`REGS_DATA_WIDTH-1){1'b0}}}) &
        (operand_b_i == {`REGS_DATA_WIDTH{1'b1}});

    wire [`REGS_DATA_WIDTH-1:0] divide_by_zero_result =
        rem_op ? operand_a_i : {`REGS_DATA_WIDTH{1'b1}};
    wire [`REGS_DATA_WIDTH-1:0] overflow_result =
        rem_op ? `REGS_DATA_WIDTH'b0 : {1'b1, {(`REGS_DATA_WIDTH-1){1'b0}}};

    wire [`REGS_DATA_WIDTH:0] divisor_ext = {1'b0, divisor_q};
    wire [`REGS_DATA_WIDTH:0] remainder_shift =
        {remainder_q[`REGS_DATA_WIDTH-1:0], dividend_q[`REGS_DATA_WIDTH-1]};
    wire [`REGS_DATA_WIDTH-1:0] dividend_shift =
        {dividend_q[`REGS_DATA_WIDTH-2:0], 1'b0};
    wire subtract_en = (remainder_shift >= divisor_ext);
    wire [`REGS_DATA_WIDTH:0] remainder_next =
        subtract_en ? (remainder_shift - divisor_ext) : remainder_shift;
    wire [`REGS_DATA_WIDTH-1:0] quotient_next =
        {quotient_q[`REGS_DATA_WIDTH-2:0], subtract_en};

    wire [`REGS_DATA_WIDTH-1:0] quotient_abs = quotient_next;
    wire [`REGS_DATA_WIDTH-1:0] remainder_abs = remainder_next[`REGS_DATA_WIDTH-1:0];
    wire [`REGS_DATA_WIDTH-1:0] quotient_result =
        quotient_neg_q ? (~quotient_abs + `REGS_DATA_WIDTH'd1) : quotient_abs;
    wire [`REGS_DATA_WIDTH-1:0] remainder_result =
        remainder_neg_q ? (~remainder_abs + `REGS_DATA_WIDTH'd1) : remainder_abs;
    wire [`REGS_DATA_WIDTH-1:0] normal_result =
        rem_result_q ? remainder_result : quotient_result;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy_q          <= 1'b0;
            done_q          <= 1'b0;
            iter_q          <= '0;
            dividend_q      <= '0;
            divisor_q       <= '0;
            quotient_q      <= '0;
            remainder_q     <= '0;
            quotient_neg_q  <= 1'b0;
            remainder_neg_q <= 1'b0;
            rem_result_q    <= 1'b0;
            result_q        <= '0;
        end else if (flush_i) begin
            busy_q          <= 1'b0;
            done_q          <= 1'b0;
            iter_q          <= '0;
            dividend_q      <= '0;
            divisor_q       <= '0;
            quotient_q      <= '0;
            remainder_q     <= '0;
            quotient_neg_q  <= 1'b0;
            remainder_neg_q <= 1'b0;
            rem_result_q    <= 1'b0;
            result_q        <= '0;
        end else begin
            done_q <= 1'b0;

            if (start_i && !busy_q) begin
                if (divisor_is_zero) begin
                    busy_q   <= 1'b0;
                    done_q   <= 1'b1;
                    result_q <= divide_by_zero_result;
                end else if (signed_overflow) begin
                    busy_q   <= 1'b0;
                    done_q   <= 1'b1;
                    result_q <= overflow_result;
                end else begin
                    busy_q          <= 1'b1;
                    iter_q          <= '0;
                    dividend_q      <= dividend_abs;
                    divisor_q       <= divisor_abs;
                    quotient_q      <= '0;
                    remainder_q     <= '0;
                    quotient_neg_q  <= dividend_neg ^ divisor_neg;
                    remainder_neg_q <= dividend_neg;
                    rem_result_q    <= rem_op;
                end
            end else if (busy_q) begin
                dividend_q  <= dividend_shift;
                quotient_q  <= quotient_next;
                remainder_q <= remainder_next;

                if (iter_q == DIV_ITER_LAST) begin
                    busy_q   <= 1'b0;
                    done_q   <= 1'b1;
                    result_q <= normal_result;
                end else begin
                    iter_q <= iter_q + 6'd1;
                end
            end
        end
    end

    assign busy_o   = busy_q;
    assign done_o   = done_q;
    assign result_o = result_q;

endmodule
