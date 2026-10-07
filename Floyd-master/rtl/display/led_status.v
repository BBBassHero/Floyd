`include "parameters.vh"

// LED 状态指示：
// led0：系统心跳，约 1 Hz 闪烁，表示 FPGA 正在运行。
// led1：输入活动指示，按键或编码器有事件时翻转。
module led_status (
    input  wire clk,
    input  wire rst_n,
    input  wire key_activity,   // 按键活动脉冲
    input  wire enc_activity,   // 编码器活动脉冲
    output reg  led0,
    output reg  led1
);

    // 心跳：50 MHz / 50 M = 1 Hz
    localparam integer HEARTBEAT_MAX = `FLOYD_SYS_CLK_HZ / 2; // 0.5 s 翻转一次

    reg [31:0] heartbeat_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            heartbeat_cnt <= 32'd0;
            led0          <= 1'b0;
        end else if (heartbeat_cnt >= HEARTBEAT_MAX - 1) begin
            heartbeat_cnt <= 32'd0;
            led0          <= ~led0;
        end else begin
            heartbeat_cnt <= heartbeat_cnt + 32'd1;
        end
    end

    // 输入活动：按键或编码器事件时翻转，并保持一段时间
    reg [23:0] activity_hold;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            activity_hold <= 24'd0;
            led1          <= 1'b0;
        end else if (key_activity || enc_activity) begin
            activity_hold <= 24'hFFFFFF;
            led1          <= ~led1;
        end else if (activity_hold != 24'd0) begin
            activity_hold <= activity_hold - 24'd1;
        end
    end

endmodule