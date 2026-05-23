`timescale 1ns/1ns

module perf_core_tb(
`ifdef VERILATOR_CC
    input clk,
    input rst_n
`endif
);

    localparam [31:0] UART_ADDR = 32'h8020_0080;

    string itcmfile;
    string dtcmfile;
    string test_name;
    longint timeout_cycles;
    int unsigned tohost_addr;

`ifndef VERILATOR_CC
    logic clk;
    logic rst_n;
`endif

    logic [31:0] perip_addr;
    logic        perip_wen;
    logic [3:0]  perip_mask;
    logic [31:0] perip_wdata;
    logic [31:0] perip_rdata;

    longint cycle_count;
    longint inst_count;
    logic [31:0] last_pc;
    logic finished;
    logic passed;
    logic [31:0] tohost_value;
    real ipc;

    wire [31:0] pc = u_dut.u_ydrasil_if_stage.pc_ff;
    wire pc_in_itcm = (pc >= 32'h8000_0000) && (pc < 32'h8000_4000);
    wire pc_in_dtcm = (pc >= 32'h8010_0000) && (pc < 32'h8014_0000);

    ydrasil_core u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .perip_addr(perip_addr),
        .perip_wen(perip_wen),
        .perip_mask(perip_mask),
        .perip_wdata(perip_wdata),
        .perip_rdata(perip_rdata)
    );

`ifndef VERILATOR_CC
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
    end
`endif

    initial begin
        if (!$value$plusargs("test_name=%s", test_name)) begin
            test_name = "unknown";
        end
        if (!$value$plusargs("timeout_cycles=%d", timeout_cycles)) begin
            timeout_cycles = 1000000;
        end
        if (!$value$plusargs("tohost_addr=%h", tohost_addr)) begin
            tohost_addr = 32'h80001000;
        end

        if ($value$plusargs("itcmfile=%s", itcmfile)) begin
            $readmemh(itcmfile, u_dut.u_ydrasil_mems.u_itcm.u_irom.mem_r);
        end else begin
            $display("ERROR: missing +itcmfile");
            $finish;
        end

        if ($value$plusargs("dtcmfile=%s", dtcmfile)) begin
            $readmemh(dtcmfile, u_dut.u_ydrasil_mems.u_dtcm.u_dram.mem_r);
        end else begin
            $display("ERROR: missing +dtcmfile");
            $finish;
        end

        $display("PERF_START: NAME=%s TOHOST=0x%08x TIMEOUT_CYCLES=%0d", test_name, tohost_addr, timeout_cycles);
    end

    always_comb begin
        perip_rdata = 32'h0;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
            inst_count <= 0;
            last_pc <= 32'h0;
            finished <= 1'b0;
            passed <= 1'b0;
            tohost_value <= 32'h0;
        end else if (!finished) begin
            cycle_count <= cycle_count + 1;
            last_pc <= pc;
            if (pc != last_pc) begin
                inst_count <= inst_count + 1;
            end

            if (perip_wen && perip_addr == UART_ADDR) begin
                $write("%c", perip_wdata[7:0]);
            end

            if (perip_wen && perip_addr == tohost_addr && perip_wdata != 32'h0) begin
                tohost_value <= perip_wdata;
                passed <= (perip_wdata == 32'h1);
                finished <= 1'b1;
            end else if (!pc_in_itcm && !pc_in_dtcm) begin
                tohost_value <= 32'hffff_fffe;
                passed <= 1'b0;
                finished <= 1'b1;
            end else if (cycle_count >= timeout_cycles) begin
                tohost_value <= 32'hffff_ffff;
                passed <= 1'b0;
                finished <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (finished) begin
            ipc = (cycle_count > 0) ? (inst_count * 1.0) / cycle_count : 0.0;
            $display("");
            $display("PERF_METRIC: NAME=%s STATUS=%s CYCLES=%0d INSTS=%0d IPC=%.4f TOHOST=0x%08x PC=0x%08x",
                test_name,
                passed ? "PASS" : "FAIL",
                cycle_count,
                inst_count,
                ipc,
                tohost_value,
                pc);
            $finish;
        end
    end

endmodule
