`timescale 1ns/1ps

`include "parameters.vh"

module waveform_rom #(
    parameter ROM_FILE = `FLOYD_SINE_ROM_FILE
) (
    input  wire [`FLOYD_WAVE_ADDR_WIDTH-1:0] addr,
    output wire signed [`FLOYD_AUDIO_WIDTH-1:0] data
);

    reg signed [`FLOYD_AUDIO_WIDTH-1:0] rom [0:`FLOYD_WAVE_TABLE_DEPTH-1];

    initial begin
        $readmemh(ROM_FILE, rom);
    end

    assign data = rom[addr];

endmodule
