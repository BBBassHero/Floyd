`timescale 1ns/1ps

`include "parameters.vh"

module tb_audio_pipeline;

    localparam integer CLK_PERIOD_NS = 10;
    localparam [31:0] PHASE_STEP_A4 = 32'h0258_BF26;

    reg clk;
    reg rst_n;
    reg sample_tick;
    reg [3:0] note_on;
    reg [3:0] note_off;
    wire [3:0] voice_active;
    wire [3:0] voice_finished;
    wire signed [`FLOYD_AUDIO_WIDTH-1:0] mixed_sample;

    audio_pipeline u_pipeline (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .voice0_note_on(note_on[0]), .voice0_note_off(note_off[0]),
        .voice0_note(7'd60), .voice0_velocity(8'hff),
        .voice0_phase_step(PHASE_STEP_A4), .voice0_waveform_select(`FLOYD_WAVE_SINE),
        .voice0_volume(8'hff),
        .voice1_note_on(note_on[1]), .voice1_note_off(note_off[1]),
        .voice1_note(7'd64), .voice1_velocity(8'hff),
        .voice1_phase_step(PHASE_STEP_A4 + 32'd1000), .voice1_waveform_select(`FLOYD_WAVE_SQUARE),
        .voice1_volume(8'hff),
        .voice2_note_on(note_on[2]), .voice2_note_off(note_off[2]),
        .voice2_note(7'd67), .voice2_velocity(8'hff),
        .voice2_phase_step(PHASE_STEP_A4 + 32'd2000), .voice2_waveform_select(`FLOYD_WAVE_TRIANGLE),
        .voice2_volume(8'hff),
        .voice3_note_on(note_on[3]), .voice3_note_off(note_off[3]),
        .voice3_note(7'd72), .voice3_velocity(8'hff),
        .voice3_phase_step(PHASE_STEP_A4 + 32'd3000), .voice3_waveform_select(`FLOYD_WAVE_SINE),
        .voice3_volume(8'hff),
        .attack_rate(8'd1),
        .decay_rate(8'd1),
        .sustain_level(8'hff),
        .release_rate(8'd1),
        .voice0_active(voice_active[0]), .voice0_finished(voice_finished[0]),
        .voice1_active(voice_active[1]), .voice1_finished(voice_finished[1]),
        .voice2_active(voice_active[2]), .voice2_finished(voice_finished[2]),
        .voice3_active(voice_active[3]), .voice3_finished(voice_finished[3]),
        .mixed_sample(mixed_sample)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    task pulse_sample_tick;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
        end
    endtask

    initial begin : test_sequence
        integer i;
        integer nonzero_count;
        reg release_done;

        rst_n = 1'b0;
        sample_tick = 1'b0;
        note_on = 4'b0000;
        note_off = 4'b0000;
        nonzero_count = 0;
        release_done = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        note_on = 4'b1111;
        @(negedge clk);
        note_on = 4'b0000;

        if (voice_active !== 4'b1111) begin
            $display("FAIL: four note_on events did not activate all voices: %b", voice_active);
            $finish;
        end

        repeat (32) begin
            pulse_sample_tick();
            if (mixed_sample !== 0)
                nonzero_count = nonzero_count + 1;
        end

        if (nonzero_count == 0) begin
            $display("FAIL: four active voices produced no mixed audio");
            $finish;
        end

        @(negedge clk);
        note_off = 4'b1111;
        @(negedge clk);
        note_off = 4'b0000;

        for (i = 0; i < 300; i = i + 1) begin
            pulse_sample_tick();
            if (voice_finished == 4'b1111)
                release_done = 1'b1;
        end

        if (!release_done || voice_active !== 4'b0000 || mixed_sample !== 0) begin
            $display("FAIL: four voices did not return to silence: active=%b sample=%0d",
                     voice_active, mixed_sample);
            $finish;
        end

        $display("PASS: four voice pipeline activation, mixing, and release checks passed");
        $finish;
    end

endmodule
