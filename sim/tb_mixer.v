`timescale 1ns/1ps

`include "parameters.vh"

module tb_mixer;

    reg signed [`FLOYD_AUDIO_WIDTH-1:0] voice_sample_0;
    reg signed [`FLOYD_AUDIO_WIDTH-1:0] voice_sample_1;
    reg signed [`FLOYD_AUDIO_WIDTH-1:0] voice_sample_2;
    reg signed [`FLOYD_AUDIO_WIDTH-1:0] voice_sample_3;
    wire signed [`FLOYD_AUDIO_WIDTH-1:0] mixed_sample;

    mixer u_mixer (
        .voice_sample_0(voice_sample_0),
        .voice_sample_1(voice_sample_1),
        .voice_sample_2(voice_sample_2),
        .voice_sample_3(voice_sample_3),
        .mixed_sample(mixed_sample)
    );

    task check_sample;
        input integer expected;
        input [8*40-1:0] label;
        begin
            #1;
            if ($signed(mixed_sample) !== expected) begin
                $display("FAIL: %0s actual=%0d expected=%0d", label, mixed_sample, expected);
                $finish;
            end
        end
    endtask

    initial begin
        voice_sample_0 = 0;
        voice_sample_1 = 0;
        voice_sample_2 = 0;
        voice_sample_3 = 0;
        check_sample(0, "all voices muted");

        voice_sample_0 = 16'sd12000;
        voice_sample_1 = 16'sd8000;
        voice_sample_2 = -16'sd4000;
        voice_sample_3 = 16'sd2000;
        check_sample(4500, "four voice scaled mix");

        voice_sample_0 = 16'sh7fff;
        voice_sample_1 = 16'sh7fff;
        voice_sample_2 = 16'sh7fff;
        voice_sample_3 = 16'sh7fff;
        check_sample(32767, "positive full-scale mix");

        voice_sample_0 = -16'sd32768;
        voice_sample_1 = -16'sd32768;
        voice_sample_2 = -16'sd32768;
        voice_sample_3 = -16'sd32768;
        check_sample(-32768, "negative full-scale mix");

        voice_sample_0 = 16'sd32767;
        voice_sample_1 = 16'sd32767;
        voice_sample_2 = 16'sd32767;
        voice_sample_3 = -16'sd32768;
        check_sample(16383, "mixed-sign boundary");

        $display("PASS: four-voice mixer scaling, saturation, and mute checks passed");
        $finish;
    end

endmodule
