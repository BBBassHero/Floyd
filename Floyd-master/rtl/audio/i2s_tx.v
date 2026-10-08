`include "parameters.vh"

// 标准 I2S 发送：16 bit、48 kHz、左右声道复制同一采样值。
// BCLK = 3.072 MHz，LRCLK = 48 kHz，BCLK/LRCLK 由 50 MHz 小数分频产生。
// 本模块只负责串行发送，不产生 sample_tick。
module i2s_tx (
    input  wire               clk,
    input  wire               rst_n,
    input  wire signed [15:0] audio_left,
    input  wire signed [15:0] audio_right,
    input  wire               audio_valid,
    output reg                i2s_bclk,
    output reg                i2s_lrclk,
    output reg                i2s_data
);

    // 50 MHz -> BCLK 翻转频率 6.144 MHz -> BCLK 3.072 MHz
    // step = 6.144e6 * 2^32 / 50e6 ≈ 527765581
    localparam [31:0] BCLK_STEP   = 32'd527765581;
    localparam integer SLOT_PER_CH = 32;
    localparam integer DATA_WIDTH  = 16;

    reg  [31:0] bclk_phase;
    wire        bclk_wrap = (bclk_phase + BCLK_STEP) < bclk_phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bclk_phase <= 32'd0;
            i2s_bclk   <= 1'b0;
        end else begin
            bclk_phase <= bclk_phase + BCLK_STEP;
            if (bclk_wrap)
                i2s_bclk <= ~i2s_bclk;
        end
    end

    // 检测 BCLK 下降沿：用移位寄存器延迟一拍
    reg bclk_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bclk_d <= 1'b0;
        else
            bclk_d <= i2s_bclk;
    end
    wire bclk_falling = bclk_d & ~i2s_bclk;

    // 锁存音频输入
    reg [15:0] shift_left;
    reg [15:0] shift_right;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_left  <= 16'd0;
            shift_right <= 16'd0;
        end else if (audio_valid) begin
            shift_left  <= audio_left;
            shift_right <= audio_right;
        end
    end

    // 发送状态机
    reg [5:0]  slot_cnt;
    reg        lr;             // 0: 左声道, 1: 右声道
    reg [15:0] shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slot_cnt  <= 6'd0;
            lr        <= 1'b0;
            i2s_lrclk <= 1'b0;
            i2s_data  <= 1'b0;
            shift_reg <= 16'd0;
        end else if (bclk_falling) begin
            if (slot_cnt == 6'd0) begin
                // 延迟槽：输出 0，加载当前声道数据
                i2s_data  <= 1'b0;
                shift_reg <= (lr == 1'b0) ? shift_left : shift_right;
                slot_cnt  <= slot_cnt + 1'b1;
            end else if (slot_cnt <= DATA_WIDTH) begin
                // MSB first
                i2s_data  <= shift_reg[15];
                shift_reg <= {shift_reg[14:0], 1'b0};
                slot_cnt  <= slot_cnt + 1'b1;
            end else if (slot_cnt < SLOT_PER_CH - 1) begin
                i2s_data <= 1'b0;
                slot_cnt <= slot_cnt + 1'b1;
            end else begin
                // 当前声道最后一个槽，切换声道
                i2s_data  <= 1'b0;
                slot_cnt  <= 6'd0;
                lr        <= ~lr;
                i2s_lrclk <= ~lr;
            end
        end
    end

endmodule