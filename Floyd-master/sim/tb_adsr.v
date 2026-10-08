`timescale 1ns/1ps

module tb_adsr;

    localparam integer CLK_PERIOD_NS = 10;
    localparam [2:0] STATE_IDLE    = 3'd0;
    localparam [2:0] STATE_ATTACK  = 3'd1;
    localparam [2:0] STATE_DECAY   = 3'd2;
    localparam [2:0] STATE_SUSTAIN = 3'd3;
    localparam [2:0] STATE_RELEASE = 3'd4;

    reg clk;
    reg rst_n;
    reg sample_tick;
    reg note_on;
    reg note_off;
    reg [7:0] attack_rate;
    reg [7:0] decay_rate;
    reg [7:0] sustain_level;
    reg [7:0] release_rate;

    wire [7:0] envelope_level;
    wire voice_finished;
    wire [2:0] state;

    adsr u_adsr (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .note_on(note_on),
        .note_off(note_off),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .envelope_level(envelope_level),
        .voice_finished(voice_finished),
        .state(state)
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
            note_on = 1'b1;
            @(negedge clk);
            note_on = 1'b0;
        end
    endtask

    task pulse_note_off;
        begin
            @(negedge clk);
            note_off = 1'b1;
            @(negedge clk);
            note_off = 1'b0;
        end
    endtask

    task expect_state;
        input [2:0] expected;
        input [8*16-1:0] label;
        begin
            if (state !== expected) begin
                $display("FAIL: %0s, expected state %0d, got %0d", label, expected, state);
                $finish;
            end
        end
    endtask

    integer i;
    initial begin
        $dumpfile("simulation_outputs/tb_adsr.vcd");
        $dumpvars(0, tb_adsr);

        rst_n        = 1'b0;
        sample_tick  = 1'b0;
        note_on      = 1'b0;
        note_off     = 1'b0;
        attack_rate  = 8'd1;
        decay_rate   = 8'd1;
        sustain_level = 8'd3;
        release_rate = 8'd1;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        expect_state(STATE_IDLE, "reset");
        if (envelope_level !== 8'd0) begin
            $display("FAIL: reset envelope is not zero");
            $finish;
        end

        pulse_note_on();
        expect_state(STATE_ATTACK, "note_on enters attack");

        pulse_sample_tick();
        if (envelope_level !== 8'd1) begin
            $display("FAIL: attack did not increment to 1, got %0d", envelope_level);
            $finish;
        end
        pulse_sample_tick();
        if (envelope_level !== 8'd2) begin
            $display("FAIL: attack did not increment to 2, got %0d", envelope_level);
            $finish;
        end
        for (i = 0; i < 253; i = i + 1) begin
            pulse_sample_tick();
        end
        expect_state(STATE_DECAY, "attack enters decay");
        if (envelope_level !== 8'hff) begin
            $display("FAIL: attack did not reach maximum");
            $finish;
        end

        for (i = 0; i < 252; i = i + 1) begin
            pulse_sample_tick();
        end
        expect_state(STATE_SUSTAIN, "decay enters sustain");
        if (envelope_level !== sustain_level) begin
            $display("FAIL: sustain level is %0d, got %0d", sustain_level, envelope_level);
            $finish;
        end

        pulse_note_off();
        expect_state(STATE_RELEASE, "note_off enters release");

        // Retrigger before release finishes.
        pulse_sample_tick();
        pulse_note_on();
        if (state !== STATE_ATTACK || envelope_level !== 8'd0) begin
            $display("FAIL: retrigger during release did not restart attack");
            $finish;
        end

        // Release the retriggered note and verify completion.
        pulse_note_off();
        pulse_sample_tick();
        if (state !== STATE_IDLE || envelope_level !== 8'd0 || !voice_finished) begin
            $display("FAIL: release did not finish cleanly, state=%0d level=%0d finished=%0d", state, envelope_level, voice_finished);
            $finish;
        end

        // A note_off while idle must not create a phantom release event.
        pulse_note_off();
        if (state !== STATE_IDLE || envelope_level !== 8'd0) begin
            $display("FAIL: idle note_off changed the envelope");
            $finish;
        end

        $display("PASS: ADSR state, timing, release, and retrigger checks passed");
        $finish;
    end

endmodule
