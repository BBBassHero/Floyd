`timescale 1ns/1ps

`include "parameters.vh"

module tb_waveform_select;

    localparam integer CLK_PERIOD_NS = 10;
    localparam [`FLOYD_PHASE_WIDTH-1:0] QUARTER_STEP = 32'h4000_0000;
    localparam signed [`FLOYD_AUDIO_WIDTH-1:0] AUDIO_MAX = 16'sh7fff;
    localparam signed [`FLOYD_AUDIO_WIDTH-1:0] AUDIO_MIN = 16'sh8000;

    reg clk;
    reg rst_n;
    reg sample_tick;
    reg enable;
    reg [`FLOYD_PHASE_WIDTH-1:0] phase_step;
    reg [2:0] waveform_select;
    wire signed [`FLOYD_AUDIO_WIDTH-1:0] audio_sample;
    wire [`FLOYD_PHASE_WIDTH-1:0] phase;

    dds_oscillator u_dds (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .enable(enable),
        .phase_step(phase_step),
        .waveform_select(waveform_select),
        .audio_sample(audio_sample),
        .phase(phase)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task pulse_sample;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
        end
    endtask

    task check_sample;
        input signed [`FLOYD_AUDIO_WIDTH-1:0] expected;
        input [8*20-1:0] label;
        begin
            if (audio_sample !== expected) begin
                $display("FAIL: %0s expected=%0d actual=%0d phase=%h", label, expected, audio_sample, phase);
                $finish;
            end
        end
    endtask

    integer i;
    initial begin
        $dumpfile("simulation_outputs/tb_waveform_select.vcd");
        $dumpvars(0, tb_waveform_select);

        rst_n = 1'b0;
        sample_tick = 1'b0;
        enable = 1'b0;
        phase_step = QUARTER_STEP;
        waveform_select = `FLOYD_WAVE_SINE;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        enable = 1'b1;

        // Square wave: phase 0 and quarter cycle are positive; half cycle
        // and three-quarter cycle are negative.
        waveform_select = `FLOYD_WAVE_SQUARE;
        pulse_sample(); check_sample(AUDIO_MAX, "square phase 0");
        pulse_sample(); check_sample(AUDIO_MAX, "square phase quarter");
        pulse_sample(); check_sample(AUDIO_MIN, "square phase half");
        pulse_sample(); check_sample(AUDIO_MIN, "square phase three-quarter");

        // Triangle wave: zero, positive peak, zero, negative peak.
        waveform_select = `FLOYD_WAVE_TRIANGLE;
        phase_step = QUARTER_STEP;
        enable = 1'b0;
        @(negedge clk);
        enable = 1'b1;
        pulse_sample(); check_sample(16'sd0, "triangle phase 0");
        pulse_sample(); check_sample(16'sd32767, "triangle phase quarter");
        pulse_sample(); check_sample(16'sd0, "triangle phase half");
        pulse_sample(); check_sample(-16'sd32767, "triangle phase three-quarter");

        $display("PASS: square and triangle waveform checks passed");
        $finish;
    end

endmodule
