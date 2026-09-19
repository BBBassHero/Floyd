`timescale 1ns/1ps

`include "../rtl/common/parameters.vh"

module tb_dds_oscillator;

    localparam integer CLK_PERIOD_NS = 20;
    localparam integer SAMPLE_DIV = 1042;
    // round(440 * 2^32 / 48000) = 0x0258BF26
    localparam integer PHASE_STEP_A4 = 32'h0258_BF26;

    reg clk;
    reg rst_n;
    reg sample_tick;
    reg enable;
    reg [`FLOYD_PHASE_WIDTH-1:0] phase_step;

    wire signed [`FLOYD_AUDIO_WIDTH-1:0] audio_sample;
    wire [`FLOYD_PHASE_WIDTH-1:0] phase;

    integer clk_count;
    integer sample_count;
    integer sample_file;

    dds_oscillator u_dds (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .enable(enable),
        .phase_step(phase_step),
        .audio_sample(audio_sample),
        .phase(phase)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    always @(posedge clk) begin
        if (!rst_n) begin
            clk_count   <= 0;
            sample_tick <= 1'b0;
        end else begin
            sample_tick <= 1'b0;
            if (clk_count == SAMPLE_DIV - 1) begin
                clk_count   <= 0;
                sample_tick <= 1'b1;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n && sample_tick && enable) begin
            sample_count = sample_count + 1;
            $fwrite(sample_file, "%0d\n", audio_sample);
        end
    end

    initial begin
        rst_n        = 1'b0;
        enable       = 1'b0;
        phase_step   = {`FLOYD_PHASE_WIDTH{1'b0}};
        clk_count    = 0;
        sample_count = 0;
        sample_file  = $fopen("dds_samples.txt", "w");

        repeat (10) @(posedge clk);
        rst_n      = 1'b1;
        enable     = 1'b1;
        phase_step = PHASE_STEP_A4;

        repeat (SAMPLE_DIV * 120) @(posedge clk);

        $fclose(sample_file);
        $display("DDS test completed, samples captured: %0d", sample_count);
        if (sample_count < 100) begin
            $display("ERROR: too few samples captured");
            $finish;
        end

        enable = 1'b0;
        repeat (4) @(posedge clk);
        if (audio_sample !== 0) begin
            $display("ERROR: output is not zero after disable");
        end else begin
            $display("PASS: output returns to zero after disable");
        end

        $finish;
    end

endmodule
