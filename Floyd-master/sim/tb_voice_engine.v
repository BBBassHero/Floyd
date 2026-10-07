`timescale 1ns/1ps

`include "parameters.vh"

module tb_voice_engine;

    localparam integer CLK_PERIOD_NS = 10;
    localparam [31:0] PHASE_STEP_A4 = 32'h0258_BF26;

    reg clk;
    reg rst_n;
    reg sample_tick;
    reg voice_note_on;
    reg voice_note_off;
    reg [6:0] voice_note;
    reg [7:0] voice_velocity;
    reg [`FLOYD_PHASE_WIDTH-1:0] phase_step;
    reg [2:0] waveform_select;
    reg [7:0] voice_volume;
    reg [7:0] attack_rate;
    reg [7:0] decay_rate;
    reg [7:0] sustain_level;
    reg [7:0] release_rate;

    wire voice_active;
    wire voice_finished;
    wire signed [`FLOYD_AUDIO_WIDTH-1:0] voice_sample;
    wire voice_active_half;
    wire voice_finished_half;
    wire signed [`FLOYD_AUDIO_WIDTH-1:0] voice_sample_half;

    voice_engine u_voice (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .voice_note_on(voice_note_on),
        .voice_note_off(voice_note_off),
        .voice_note(voice_note),
        .voice_velocity(voice_velocity),
        .phase_step(phase_step),
        .waveform_select(waveform_select),
        .voice_volume(voice_volume),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .voice_active(voice_active),
        .voice_finished(voice_finished),
        .voice_sample(voice_sample)
    );

    // A second identical voice provides a same-phase reference for the
    // Q0.8 half-volume check.
    voice_engine u_voice_half (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .voice_note_on(voice_note_on),
        .voice_note_off(voice_note_off),
        .voice_note(voice_note),
        .voice_velocity(voice_velocity),
        .phase_step(phase_step),
        .waveform_select(waveform_select),
        .voice_volume(8'd128),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .voice_active(voice_active_half),
        .voice_finished(voice_finished_half),
        .voice_sample(voice_sample_half)
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

    task pulse_note_on;
        begin
            @(negedge clk);
            voice_note_on = 1'b1;
            @(negedge clk);
            voice_note_on = 1'b0;
        end
    endtask

    task pulse_note_off;
        begin
            @(negedge clk);
            voice_note_off = 1'b1;
            @(negedge clk);
            voice_note_off = 1'b0;
        end
    endtask

    integer sample_count;
    integer nonzero_count;
    integer raw_product;
    integer expected_full;
    integer expected_half;
    initial begin
        $dumpfile("simulation_outputs/tb_voice_engine.vcd");
        $dumpvars(0, tb_voice_engine);

        rst_n          = 1'b0;
        sample_tick    = 1'b0;
        voice_note_on  = 1'b0;
        voice_note_off = 1'b0;
        voice_note     = 7'd69;
        voice_velocity = 8'hff;
        phase_step     = PHASE_STEP_A4;
        waveform_select = 3'd0;
        voice_volume   = 8'hff;
        attack_rate    = 8'd1;
        decay_rate     = 8'd1;
        sustain_level  = 8'hff;
        release_rate   = 8'd1;
        sample_count   = 0;
        nonzero_count  = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        if (voice_active !== 1'b0 || voice_sample !== 0) begin
            $display("FAIL: reset did not leave the voice silent, active=%b sample=%0d", voice_active, voice_sample);
            $finish;
        end

        pulse_note_on();
        if (voice_active !== 1'b1) begin
            $display("FAIL: note_on did not activate the voice");
            $finish;
        end

        repeat (8) begin
            pulse_sample_tick();
            sample_count = sample_count + 1;
            if (voice_sample !== 0) begin
                nonzero_count = nonzero_count + 1;
            end
        end

        if (sample_count != 8 || nonzero_count == 0) begin
            $display("FAIL: voice did not produce a nonzero audio sample");
            $finish;
        end

        // Both instances must have the same phase and envelope. Calculate
        // the expected outputs from the shared pre-volume signal so the test
        // checks the actual Q0.8 definition, not an approximation of full
        // volume multiplied by one half.
        if (u_voice.u_dds.phase !== u_voice_half.u_dds.phase ||
            u_voice.u_adsr.envelope_level !== u_voice_half.u_adsr.envelope_level) begin
            $display("FAIL: full and half-volume references are out of sync");
            $finish;
        end

        raw_product = $signed(u_voice.u_dds.audio_sample) * u_voice.u_adsr.envelope_level;
        expected_full = (raw_product * 255) >>> 16;
        expected_half = (raw_product * 128) >>> 16;

        if ($signed(voice_sample) !== expected_full) begin
            $display("FAIL: full-volume scaling mismatch, actual=%0d expected=%0d", voice_sample, expected_full);
            $finish;
        end
        if ($signed(voice_sample_half) !== expected_half) begin
            $display("FAIL: half-volume scaling mismatch, actual=%0d expected=%0d", voice_sample_half, expected_half);
            $finish;
        end

        voice_volume = 8'd0;
        pulse_sample_tick();
        if (voice_sample !== 0) begin
            $display("FAIL: zero volume did not mute the voice, sample=%0d", voice_sample);
            $finish;
        end
        voice_volume = 8'hff;

        pulse_note_off();
        if (voice_active !== 1'b1) begin
            $display("FAIL: voice became inactive before release completed");
            $finish;
        end

        begin : release_wait
            repeat (16) begin
                pulse_sample_tick();
                if (voice_finished) begin
                    disable release_wait;
                end
            end
        end

        if (voice_active !== 1'b0 || voice_sample !== 0 || voice_finished !== 1'b1) begin
            $display("FAIL: release did not silence and finish the voice");
            $finish;
        end

        $display("PASS: single voice activation, scaling, and release checks passed");
        $finish;
    end

endmodule
