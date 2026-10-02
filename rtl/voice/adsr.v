`timescale 1ns/1ps

`include "parameters.vh"

// ADSR envelope for one voice.
// The rate inputs are sample-tick intervals between envelope level changes.
// A rate of zero is treated as one sample tick.
module adsr #(
    parameter ENVELOPE_WIDTH = 8,
    parameter RATE_WIDTH      = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         sample_tick,
    input  wire                         note_on,
    input  wire                         note_off,
    input  wire [RATE_WIDTH-1:0]        attack_rate,
    input  wire [RATE_WIDTH-1:0]        decay_rate,
    input  wire [ENVELOPE_WIDTH-1:0]    sustain_level,
    input  wire [RATE_WIDTH-1:0]        release_rate,
    output reg  [ENVELOPE_WIDTH-1:0]    envelope_level,
    output reg                           voice_finished,
    output reg  [`FLOYD_ADSR_STATE_WIDTH-1:0] state
);

    

    localparam [ENVELOPE_WIDTH-1:0] LEVEL_MAX = {ENVELOPE_WIDTH{1'b1}};

    reg [RATE_WIDTH-1:0] rate_counter;

    // Treat zero as the fastest useful rate: one update per sample tick.
    wire [RATE_WIDTH-1:0] attack_period  = (attack_rate  == {RATE_WIDTH{1'b0}}) ? {{(RATE_WIDTH-1){1'b0}}, 1'b1} : attack_rate;
    wire [RATE_WIDTH-1:0] decay_period   = (decay_rate   == {RATE_WIDTH{1'b0}}) ? {{(RATE_WIDTH-1){1'b0}}, 1'b1} : decay_rate;
    wire [RATE_WIDTH-1:0] release_period = (release_rate == {RATE_WIDTH{1'b0}}) ? {{(RATE_WIDTH-1){1'b0}}, 1'b1} : release_rate;

    wire rate_elapsed = (rate_counter == {RATE_WIDTH{1'b0}});

    always @(posedge clk) begin
        if (!rst_n) begin
            envelope_level <= {ENVELOPE_WIDTH{1'b0}};
            voice_finished <= 1'b0;
            state          <= `FLOYD_ADSR_STATE_IDLE;
            rate_counter   <= {RATE_WIDTH{1'b0}};
        end else begin
            voice_finished <= 1'b0;

            // Note events have priority over level updates. This permits a
            // voice to be retriggered cleanly while it is releasing.
            if (note_on) begin
                envelope_level <= {ENVELOPE_WIDTH{1'b0}};
                state          <= `FLOYD_ADSR_STATE_ATTACK;
                rate_counter   <= {RATE_WIDTH{1'b0}};
            end else if (note_off && (state != `FLOYD_ADSR_STATE_IDLE)) begin
                state        <= `FLOYD_ADSR_STATE_RELEASE;
                rate_counter <= {RATE_WIDTH{1'b0}};
            end else if (sample_tick) begin
                case (state)
                    `FLOYD_ADSR_STATE_IDLE: begin
                        envelope_level <= {ENVELOPE_WIDTH{1'b0}};
                        rate_counter   <= {RATE_WIDTH{1'b0}};
                    end

                    `FLOYD_ADSR_STATE_ATTACK: begin
                        if (rate_elapsed) begin
                            rate_counter <= attack_period - {{(RATE_WIDTH-1){1'b0}}, 1'b1};
                            if (envelope_level >= LEVEL_MAX - {{(ENVELOPE_WIDTH-1){1'b0}}, 1'b1}) begin
                                envelope_level <= LEVEL_MAX;
                                state          <= `FLOYD_ADSR_STATE_DECAY;
                                rate_counter   <= {RATE_WIDTH{1'b0}};
                            end else begin
                                envelope_level <= envelope_level + {{(ENVELOPE_WIDTH-1){1'b0}}, 1'b1};
                            end
                        end else begin
                            rate_counter <= rate_counter - {{(RATE_WIDTH-1){1'b0}}, 1'b1};
                        end
                    end

                    `FLOYD_ADSR_STATE_DECAY: begin
                        if (rate_elapsed) begin
                            rate_counter <= decay_period - {{(RATE_WIDTH-1){1'b0}}, 1'b1};
                            // Enter sustain on the same tick that the next
                            // decay step would reach or cross sustain_level.
                            if ((envelope_level <= sustain_level) ||
                                (envelope_level != {ENVELOPE_WIDTH{1'b0}} &&
                                 ((envelope_level - {{(ENVELOPE_WIDTH-1){1'b0}}, 1'b1}) <= sustain_level))) begin
                                envelope_level <= sustain_level;
                                state          <= `FLOYD_ADSR_STATE_SUSTAIN;
                                rate_counter   <= {RATE_WIDTH{1'b0}};
                            end else begin
                                envelope_level <= envelope_level - {{(ENVELOPE_WIDTH-1){1'b0}}, 1'b1};
                            end
                        end else begin
                            rate_counter <= rate_counter - {{(RATE_WIDTH-1){1'b0}}, 1'b1};
                        end
                    end

                    `FLOYD_ADSR_STATE_SUSTAIN: begin
                        envelope_level <= sustain_level;
                        rate_counter   <= {RATE_WIDTH{1'b0}};
                    end

                    `FLOYD_ADSR_STATE_RELEASE: begin
                        if (rate_elapsed) begin
                            rate_counter <= release_period - {{(RATE_WIDTH-1){1'b0}}, 1'b1};
                            if (envelope_level <= {{(ENVELOPE_WIDTH-1){1'b0}}, 1'b1}) begin
                                envelope_level <= {ENVELOPE_WIDTH{1'b0}};
                                state          <= `FLOYD_ADSR_STATE_IDLE;
                                voice_finished <= 1'b1;
                                rate_counter   <= {RATE_WIDTH{1'b0}};
                            end else begin
                                envelope_level <= envelope_level - {{(ENVELOPE_WIDTH-1){1'b0}}, 1'b1};
                            end
                        end else begin
                            rate_counter <= rate_counter - {{(RATE_WIDTH-1){1'b0}}, 1'b1};
                        end
                    end

                    default: begin
                        envelope_level <= {ENVELOPE_WIDTH{1'b0}};
                        state          <= `FLOYD_ADSR_STATE_IDLE;
                        rate_counter   <= {RATE_WIDTH{1'b0}};
                    end
                endcase
            end
        end
    end

endmodule
