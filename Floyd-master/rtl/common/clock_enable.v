`include "parameters.vh"

module clock_enable (
    input  wire clk,
    input  wire rst_n,
    output reg  sample_tick,    // 48kHz 采样使能脉冲
    output reg  key_scan_tick   // 1kHz 按键扫描使能脉冲
);

    // ------------------------------------------------------------
    // 音频采样使能：使用 32 位相位累加器产生 48kHz 平均频率
    // 步长 = 48000 * 2^32 / 50000000 ≈ 4123168.604
    // 实际频率 = 50MHz * 4123168604 / 2^32 ≈ 48000.0 Hz
    // ------------------------------------------------------------
    localparam [31:0] SAMPLE_STEP = 32'd4123168604;

    reg [31:0] phase_acc;
    reg        sample_tick_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc     <= 32'd0;
            sample_tick_r <= 1'b0;
        end else begin
            phase_acc     <= phase_acc + SAMPLE_STEP;
            sample_tick_r <= (phase_acc + SAMPLE_STEP) < phase_acc; // 溢出产生脉冲
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sample_tick <= 1'b0;
        else
            sample_tick <= sample_tick_r;
    end

    // ------------------------------------------------------------
    // 按键扫描使能：1kHz，50MHz / 1kHz = 50000
    // ------------------------------------------------------------
    localparam integer KEY_SCAN_CNT_MAX = `FLOYD_SYS_CLK_HZ / 1000; // 50000

    reg [31:0] key_scan_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_scan_cnt  <= 32'd0;
            key_scan_tick <= 1'b0;
        end else if (key_scan_cnt >= KEY_SCAN_CNT_MAX - 1) begin
            key_scan_cnt  <= 32'd0;
            key_scan_tick <= 1'b1;
        end else begin
            key_scan_cnt  <= key_scan_cnt + 32'd1;
            key_scan_tick <= 1'b0;
        end
    end

endmodule