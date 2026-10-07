`timescale 1ns/1ps

`include "parameters.vh"

module waveform_rom #(
    parameter SINE_ROM_FILE     = `FLOYD_SINE_ROM_FILE,
    parameter SQUARE_ROM_FILE   = `FLOYD_SQUARE_ROM_FILE,
    parameter TRIANGLE_ROM_FILE = `FLOYD_TRIANGLE_ROM_FILE
) (
    input  wire [`FLOYD_WAVE_ADDR_WIDTH-1:0] addr,
    input  wire [2:0]                        waveform_select,
    output wire signed [`FLOYD_AUDIO_WIDTH-1:0] data
);

    reg signed [`FLOYD_AUDIO_WIDTH-1:0] sine_rom [0:`FLOYD_WAVE_TABLE_DEPTH-1];
    reg signed [`FLOYD_AUDIO_WIDTH-1:0] square_rom [0:`FLOYD_WAVE_TABLE_DEPTH-1];
    reg signed [`FLOYD_AUDIO_WIDTH-1:0] triangle_rom [0:`FLOYD_WAVE_TABLE_DEPTH-1];
    reg signed [`FLOYD_AUDIO_WIDTH-1:0] selected_data;

    initial begin
        $readmemh(SINE_ROM_FILE, sine_rom);
        $readmemh(SQUARE_ROM_FILE, square_rom);
        $readmemh(TRIANGLE_ROM_FILE, triangle_rom);
    end

    // All waveforms use the same phase-derived address. Only the selected
    // table changes, so switching waveforms preserves the DDS phase.
    always @* begin
        selected_data = sine_rom[addr];

        case (waveform_select)
            `FLOYD_WAVE_SQUARE: begin
                selected_data = square_rom[addr];
            end

            `FLOYD_WAVE_TRIANGLE: begin
                selected_data = triangle_rom[addr];
            end

            default: begin
                selected_data = sine_rom[addr];
            end
        endcase
    end

    assign data = selected_data;

endmodule
