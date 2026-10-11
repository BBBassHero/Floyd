`timescale 1ns/1ps

`include "parameters.vh"

// Four-voice audio mixer. The four input samples are summed in an 18-bit
// accumulator, attenuated by four (one right shift per possible voice bit),
// and saturated back to the 16-bit DAC sample range.
module mixer #(
    parameter AUDIO_WIDTH = `FLOYD_AUDIO_WIDTH
) (
    input  wire signed [AUDIO_WIDTH-1:0] voice_sample_0,
    input  wire signed [AUDIO_WIDTH-1:0] voice_sample_1,
    input  wire signed [AUDIO_WIDTH-1:0] voice_sample_2,
    input  wire signed [AUDIO_WIDTH-1:0] voice_sample_3,
    output reg  signed [AUDIO_WIDTH-1:0] mixed_sample
);

    localparam integer MIX_WIDTH = AUDIO_WIDTH + 2;
    localparam signed [MIX_WIDTH-1:0] AUDIO_MAX = (1 << (AUDIO_WIDTH - 1)) - 1;
    localparam signed [MIX_WIDTH-1:0] AUDIO_MIN = -(1 << (AUDIO_WIDTH - 1));

    reg signed [MIX_WIDTH-1:0] mix_sum;
    reg signed [MIX_WIDTH-1:0] scaled_sum;
    wire signed [MIX_WIDTH-1:0] extended_sample_0 = voice_sample_0;
    wire signed [MIX_WIDTH-1:0] extended_sample_1 = voice_sample_1;
    wire signed [MIX_WIDTH-1:0] extended_sample_2 = voice_sample_2;
    wire signed [MIX_WIDTH-1:0] extended_sample_3 = voice_sample_3;

    always @* begin
        mix_sum = extended_sample_0 + extended_sample_1 +
                  extended_sample_2 + extended_sample_3;
        scaled_sum = mix_sum >>> 2;

        if (scaled_sum > AUDIO_MAX) begin
            mixed_sample = {1'b0, {(AUDIO_WIDTH-1){1'b1}}};
        end else if (scaled_sum < AUDIO_MIN) begin
            mixed_sample = {1'b1, {(AUDIO_WIDTH-1){1'b0}}};
        end else begin
            mixed_sample = scaled_sum[AUDIO_WIDTH-1:0];
        end
    end

endmodule
