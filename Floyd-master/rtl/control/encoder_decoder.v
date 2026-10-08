`include "parameters.vh"

module encoder_decoder (
    input  wire clk,
    input  wire rst_n,
    input  wire enc_a,
    input  wire enc_b,
    output reg  enc_step,   // 单周期脉冲
    output reg  enc_dir     // 0: 正转，1: 反转
);

    // 两级同步
    reg a_meta, a_sync;
    reg b_meta, b_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_meta <= 1'b1;
            a_sync <= 1'b1;
            b_meta <= 1'b1;
            b_sync <= 1'b1;
        end else begin
            a_meta <= enc_a;
            a_sync <= a_meta;
            b_meta <= enc_b;
            b_sync <= b_meta;
        end
    end

    // 状态机
    reg [1:0] state, state_next;
    localparam S00 = 2'b00, S01 = 2'b01, S11 = 2'b11, S10 = 2'b10;

    always @(*) begin
        state_next = {a_sync, b_sync};
    end

    // 方向判断与脉冲
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S11;
            enc_step <= 1'b0;
            enc_dir  <= 1'b0;
        end else begin
            enc_step <= 1'b0;
            if (state_next != state) begin
                case ({state, state_next})
                    {S00, S01}, {S01, S11}, {S11, S10}, {S10, S00}: begin
                        enc_dir  <= 1'b0; // 正转
                        enc_step <= 1'b1;
                    end
                    {S00, S10}, {S10, S11}, {S11, S01}, {S01, S00}: begin
                        enc_dir  <= 1'b1; // 反转
                        enc_step <= 1'b1;
                    end
                    default: ;
                endcase
                state <= state_next;
            end
        end
    end

endmodule