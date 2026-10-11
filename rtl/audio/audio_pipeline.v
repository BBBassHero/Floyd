`timescale 1ns/1ps

`include "parameters.vh"

// Four-voice synthesis pipeline. Voice allocation and phase-step generation
// remain outside this module; this block only owns voice engines and mixing.
module audio_pipeline #(
    parameter AUDIO_WIDTH    = `FLOYD_AUDIO_WIDTH,
    parameter PHASE_WIDTH    = `FLOYD_PHASE_WIDTH,
    parameter ENVELOPE_WIDTH = 8,
    parameter RATE_WIDTH     = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_tick,

    input  wire                         voice0_note_on,
    input  wire                         voice0_note_off,
    input  wire [6:0]                   voice0_note,
    input  wire [7:0]                   voice0_velocity,
    input  wire [PHASE_WIDTH-1:0]       voice0_phase_step,
    input  wire [2:0]                   voice0_waveform_select,
    input  wire [7:0]                   voice0_volume,

    input  wire                         voice1_note_on,
    input  wire                         voice1_note_off,
    input  wire [6:0]                   voice1_note,
    input  wire [7:0]                   voice1_velocity,
    input  wire [PHASE_WIDTH-1:0]       voice1_phase_step,
    input  wire [2:0]                   voice1_waveform_select,
    input  wire [7:0]                   voice1_volume,

    input  wire                         voice2_note_on,
    input  wire                         voice2_note_off,
    input  wire [6:0]                   voice2_note,
    input  wire [7:0]                   voice2_velocity,
    input  wire [PHASE_WIDTH-1:0]       voice2_phase_step,
    input  wire [2:0]                   voice2_waveform_select,
    input  wire [7:0]                   voice2_volume,

    input  wire                         voice3_note_on,
    input  wire                         voice3_note_off,
    input  wire [6:0]                   voice3_note,
    input  wire [7:0]                   voice3_velocity,
    input  wire [PHASE_WIDTH-1:0]       voice3_phase_step,
    input  wire [2:0]                   voice3_waveform_select,
    input  wire [7:0]                   voice3_volume,

    input  wire [RATE_WIDTH-1:0]        attack_rate,
    input  wire [RATE_WIDTH-1:0]        decay_rate,
    input  wire [ENVELOPE_WIDTH-1:0]    sustain_level,
    input  wire [RATE_WIDTH-1:0]        release_rate,

    output wire                         voice0_active,
    output wire                         voice0_finished,
    output wire                         voice1_active,
    output wire                         voice1_finished,
    output wire                         voice2_active,
    output wire                         voice2_finished,
    output wire                         voice3_active,
    output wire                         voice3_finished,
    output wire signed [AUDIO_WIDTH-1:0] mixed_sample
);

    wire signed [AUDIO_WIDTH-1:0] voice_sample_0;
    wire signed [AUDIO_WIDTH-1:0] voice_sample_1;
    wire signed [AUDIO_WIDTH-1:0] voice_sample_2;
    wire signed [AUDIO_WIDTH-1:0] voice_sample_3;

    voice_engine #(
        .AUDIO_WIDTH(AUDIO_WIDTH), .PHASE_WIDTH(PHASE_WIDTH),
        .ENVELOPE_WIDTH(ENVELOPE_WIDTH), .RATE_WIDTH(RATE_WIDTH)
    ) u_voice_0 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .voice_note_on(voice0_note_on), .voice_note_off(voice0_note_off),
        .voice_note(voice0_note), .voice_velocity(voice0_velocity),
        .phase_step(voice0_phase_step), .waveform_select(voice0_waveform_select),
        .voice_volume(voice0_volume), .attack_rate(attack_rate),
        .decay_rate(decay_rate), .sustain_level(sustain_level),
        .release_rate(release_rate), .voice_active(voice0_active),
        .voice_finished(voice0_finished), .voice_sample(voice_sample_0)
    );

    voice_engine #(
        .AUDIO_WIDTH(AUDIO_WIDTH), .PHASE_WIDTH(PHASE_WIDTH),
        .ENVELOPE_WIDTH(ENVELOPE_WIDTH), .RATE_WIDTH(RATE_WIDTH)
    ) u_voice_1 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .voice_note_on(voice1_note_on), .voice_note_off(voice1_note_off),
        .voice_note(voice1_note), .voice_velocity(voice1_velocity),
        .phase_step(voice1_phase_step), .waveform_select(voice1_waveform_select),
        .voice_volume(voice1_volume), .attack_rate(attack_rate),
        .decay_rate(decay_rate), .sustain_level(sustain_level),
        .release_rate(release_rate), .voice_active(voice1_active),
        .voice_finished(voice1_finished), .voice_sample(voice_sample_1)
    );

    voice_engine #(
        .AUDIO_WIDTH(AUDIO_WIDTH), .PHASE_WIDTH(PHASE_WIDTH),
        .ENVELOPE_WIDTH(ENVELOPE_WIDTH), .RATE_WIDTH(RATE_WIDTH)
    ) u_voice_2 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .voice_note_on(voice2_note_on), .voice_note_off(voice2_note_off),
        .voice_note(voice2_note), .voice_velocity(voice2_velocity),
        .phase_step(voice2_phase_step), .waveform_select(voice2_waveform_select),
        .voice_volume(voice2_volume), .attack_rate(attack_rate),
        .decay_rate(decay_rate), .sustain_level(sustain_level),
        .release_rate(release_rate), .voice_active(voice2_active),
        .voice_finished(voice2_finished), .voice_sample(voice_sample_2)
    );

    voice_engine #(
        .AUDIO_WIDTH(AUDIO_WIDTH), .PHASE_WIDTH(PHASE_WIDTH),
        .ENVELOPE_WIDTH(ENVELOPE_WIDTH), .RATE_WIDTH(RATE_WIDTH)
    ) u_voice_3 (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .voice_note_on(voice3_note_on), .voice_note_off(voice3_note_off),
        .voice_note(voice3_note), .voice_velocity(voice3_velocity),
        .phase_step(voice3_phase_step), .waveform_select(voice3_waveform_select),
        .voice_volume(voice3_volume), .attack_rate(attack_rate),
        .decay_rate(decay_rate), .sustain_level(sustain_level),
        .release_rate(release_rate), .voice_active(voice3_active),
        .voice_finished(voice3_finished), .voice_sample(voice_sample_3)
    );

    mixer #(.AUDIO_WIDTH(AUDIO_WIDTH)) u_mixer (
        .voice_sample_0(voice_sample_0), .voice_sample_1(voice_sample_1),
        .voice_sample_2(voice_sample_2), .voice_sample_3(voice_sample_3),
        .mixed_sample(mixed_sample)
    );

endmodule
