`timescale 1ns/1ps

`include "parameters.vh"

// One complete synthesizer voice: DDS oscillator followed by an ADSR
// amplitude envelope and a per-voice volume control.
module voice_engine #(
    parameter AUDIO_WIDTH    = `FLOYD_AUDIO_WIDTH,
    parameter PHASE_WIDTH    = `FLOYD_PHASE_WIDTH,
    parameter ENVELOPE_WIDTH = 8,
    parameter RATE_WIDTH     = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_tick,
    input  wire                         voice_note_on,
    input  wire                         voice_note_off,
    input  wire [6:0]                   voice_note,
    input  wire [7:0]                   voice_velocity,
    input  wire [PHASE_WIDTH-1:0]       phase_step,
    input  wire [2:0]                   waveform_select,
    input  wire [7:0]                   voice_volume,
    input  wire [RATE_WIDTH-1:0]        attack_rate,
    input  wire [RATE_WIDTH-1:0]        decay_rate,
    input  wire [ENVELOPE_WIDTH-1:0]    sustain_level,
    input  wire [RATE_WIDTH-1:0]        release_rate,
    output wire                         voice_active,
    output wire                         voice_finished,
    output reg  signed [AUDIO_WIDTH-1:0] voice_sample
);

    wire signed [AUDIO_WIDTH-1:0] oscillator_sample;
    wire [PHASE_WIDTH-1:0] oscillator_phase;
    wire [ENVELOPE_WIDTH-1:0] envelope_level;
    wire [`FLOYD_ADSR_STATE_WIDTH-1:0] envelope_state;

    localparam signed [AUDIO_WIDTH:0] AUDIO_MAX = {2'b00, {AUDIO_WIDTH-1{1'b1}}};
    localparam signed [AUDIO_WIDTH:0] AUDIO_MIN = {2'b11, {AUDIO_WIDTH-1{1'b0}}};

    // The note and velocity are part of the shared voice interface. The
    // voice manager converts the note to phase_step before this module.
    wire unused_inputs = ^{voice_note, voice_velocity};

    assign voice_active = (envelope_state != `FLOYD_ADSR_STATE_IDLE);

    dds_oscillator #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .AUDIO_WIDTH(AUDIO_WIDTH)
    ) u_dds (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .enable(voice_active),
        .phase_step(phase_step),
        .waveform_select(waveform_select),
        .audio_sample(oscillator_sample),
        .phase(oscillator_phase)
    );

    adsr #(
        .ENVELOPE_WIDTH(ENVELOPE_WIDTH),
        .RATE_WIDTH(RATE_WIDTH)
    ) u_adsr (
        .clk(clk),
        .rst_n(rst_n),
        .sample_tick(sample_tick),
        .note_on(voice_note_on),
        .note_off(voice_note_off),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .envelope_level(envelope_level),
        .voice_finished(voice_finished),
        .state(envelope_state)
    );

    // The product is wider than the audio sample. Both controls are Q0.8,
    // so two right shifts restore the original audio scale.
    reg signed [AUDIO_WIDTH+ENVELOPE_WIDTH+8-1:0] envelope_product;
    reg signed [AUDIO_WIDTH+ENVELOPE_WIDTH+16-1:0] volume_product;
    reg signed [AUDIO_WIDTH+ENVELOPE_WIDTH+16-1:0] scaled_sample;

    always @* begin
        envelope_product = oscillator_sample * $signed({1'b0, envelope_level});
        volume_product   = envelope_product * $signed({1'b0, voice_volume});
        scaled_sample    = volume_product >>> (ENVELOPE_WIDTH + 8);

        if (!voice_active) begin
            voice_sample = {AUDIO_WIDTH{1'b0}};
        end else if (scaled_sample > AUDIO_MAX) begin
            voice_sample = {1'b0, {AUDIO_WIDTH-1{1'b1}}};
        end else if (scaled_sample < AUDIO_MIN) begin
            voice_sample = {1'b1, {AUDIO_WIDTH-1{1'b0}}};
        end else begin
            voice_sample = scaled_sample[AUDIO_WIDTH-1:0];
        end
    end

endmodule
