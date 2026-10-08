`timescale 1ns/1ps

module tb_i2s_tx;

    localparam integer CLK_PERIOD_NS = 20;  // 50 MHz

    reg clk;
    reg rst_n;
    reg signed [15:0] audio_left;
    reg signed [15:0] audio_right;
    reg audio_valid;

    wire i2s_bclk;
    wire i2s_lrclk;
    wire i2s_data;

    i2s_tx u_i2s_tx (
        .clk         (clk),
        .rst_n       (rst_n),
        .audio_left  (audio_left),
        .audio_right (audio_right),
        .audio_valid (audio_valid),
        .i2s_bclk    (i2s_bclk),
        .i2s_lrclk   (i2s_lrclk),
        .i2s_data    (i2s_data)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    integer bclk_edges;
    always @(posedge i2s_bclk) bclk_edges = bclk_edges + 1;

    initial begin
        $dumpfile("simulation_outputs/tb_i2s_tx.vcd");
        $dumpvars(0, tb_i2s_tx);

        rst_n       = 1'b0;
        audio_left  = 16'sd0;
        audio_right = 16'sd0;
        audio_valid = 1'b0;
        bclk_edges  = 0;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        // 发送 10 个采样
        repeat (10) begin
            @(posedge clk);
            audio_left  = 16'sd1000;
            audio_right = -16'sd1000;
            audio_valid = 1'b1;
            @(posedge clk);
            audio_valid = 1'b0;
            repeat (2000) @(posedge clk);
        end

        $display("PASS: i2s_tx completed, bclk_edges=%0d", bclk_edges);
        $finish;
    end

endmodule