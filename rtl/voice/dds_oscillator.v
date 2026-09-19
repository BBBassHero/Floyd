`timescale 1ns/1ps

`include "parameters.vh"

module dds_oscillator #(
    parameter PHASE_WIDTH = `FLOYD_PHASE_WIDTH,
    parameter AUDIO_WIDTH = `FLOYD_AUDIO_WIDTH
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_tick,
    input  wire                         enable,
    input  wire [PHASE_WIDTH-1:0]       phase_step,
    output reg  signed [AUDIO_WIDTH-1:0] audio_sample,
    output wire [PHASE_WIDTH-1:0]       phase
);

    reg [PHASE_WIDTH-1:0] phase_acc;
    wire [`FLOYD_WAVE_ADDR_WIDTH-1:0] wave_addr;
    wire signed [AUDIO_WIDTH-1:0] wave_sample;

    assign wave_addr = phase_acc[PHASE_WIDTH-1 -: `FLOYD_WAVE_ADDR_WIDTH];
    assign phase = phase_acc;

    waveform_rom u_waveform_rom (
        .addr(wave_addr),
        .data(wave_sample)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            phase_acc    <= {PHASE_WIDTH{1'b0}};
            audio_sample <= {AUDIO_WIDTH{1'b0}};
        end else if (!enable) begin
            phase_acc    <= {PHASE_WIDTH{1'b0}};
            audio_sample <= {AUDIO_WIDTH{1'b0}};
        end else if (sample_tick) begin
            phase_acc    <= phase_acc + phase_step;
            audio_sample <= wave_sample;
        end
    end

endmodule
