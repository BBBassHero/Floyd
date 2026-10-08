`include "parameters.vh"

// 4x4 矩阵键盘 + 2 个板载按键扫描。
// 矩阵键码 0~15，板载键码 0~1。
// 所有事件均为单周期脉冲。
module key_scan (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       key_scan_tick,   // 1 kHz 扫描脉冲
    // 4x4 矩阵键盘
    input  wire [3:0] key_col,         // 列输入，低有效
    output reg  [3:0] key_row,         // 行输出，低有效
    // 板载按键，低有效
    input  wire       key0,
    input  wire       key1,
    // 矩阵键盘事件
    output reg  [3:0] key_code,        // 0~15，空闲为 4'hF
    output reg        key_pressed,
    output reg        key_released,
    // 板载按键事件
    output reg  [1:0] btn_code,        // 0~1
    output reg        btn_pressed,
    output reg        btn_released
);

    localparam [3:0] NO_KEY       = 4'hF;
    localparam [3:0] DEBOUNCE_MAX = 4'd8;

    // ------------------------------------------------------------
    // 矩阵扫描
    // ------------------------------------------------------------
    reg [1:0] scan_row;
    reg [3:0] current_code;
    reg [3:0] last_code;
    reg [3:0] stable_code;
    reg [3:0] last_stable;
    reg [3:0] debounce_cnt;

    // 组合逻辑：根据 scan_row 驱动对应行
    always @* begin
        case (scan_row)
            2'd0: key_row = 4'b1110;
            2'd1: key_row = 4'b1101;
            2'd2: key_row = 4'b1011;
            2'd3: key_row = 4'b0111;
            default: key_row = 4'b1111;
        endcase
    end

    // 组合逻辑：读列并编码键码
    always @* begin
        if      (key_col[0] == 1'b0) current_code = {scan_row, 2'd0};
        else if (key_col[1] == 1'b0) current_code = {scan_row, 2'd1};
        else if (key_col[2] == 1'b0) current_code = {scan_row, 2'd2};
        else if (key_col[3] == 1'b0) current_code = {scan_row, 2'd3};
        else                          current_code = NO_KEY;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_row     <= 2'd0;
            key_code     <= 4'h0;
            key_pressed  <= 1'b0;
            key_released <= 1'b0;
            last_code    <= NO_KEY;
            stable_code  <= NO_KEY;
            last_stable  <= NO_KEY;
            debounce_cnt <= 4'd0;
        end else begin
            key_pressed  <= 1'b0;
            key_released <= 1'b0;

            if (key_scan_tick) begin
                // 切换扫描行
                scan_row <= scan_row + 1'b1;

                // 消抖：连续 DEBOUNCE_MAX 次相同才更新稳定键码
                if (current_code == last_code) begin
                    if (debounce_cnt < DEBOUNCE_MAX)
                        debounce_cnt <= debounce_cnt + 1'b1;
                    else
                        stable_code <= current_code;
                end else begin
                    last_code    <= current_code;
                    debounce_cnt <= 4'd0;
                end

                // 检测稳定键码变化
                if (stable_code != last_stable) begin
                    if (stable_code != NO_KEY) begin
                        key_pressed <= 1'b1;
                        key_code    <= stable_code;
                    end else begin
                        key_released <= 1'b1;
                    end
                    last_stable <= stable_code;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // 板载按键消抖
    // ------------------------------------------------------------
    reg [3:0] btn0_cnt, btn1_cnt;
    reg       btn0_stable, btn1_stable;
    reg       btn0_last, btn1_last;
    localparam [3:0] BTN_DEBOUNCE_MAX = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn0_cnt    <= 4'd0;
            btn1_cnt    <= 4'd0;
            btn0_stable <= 1'b1;
            btn1_stable <= 1'b1;
            btn0_last   <= 1'b1;
            btn1_last   <= 1'b1;
            btn_code    <= 2'd0;
            btn_pressed <= 1'b0;
            btn_released<= 1'b0;
        end else begin
            btn_pressed  <= 1'b0;
            btn_released <= 1'b0;

            if (key_scan_tick) begin
                // key0 消抖
                if (key0 == btn0_last) begin
                    if (btn0_cnt < BTN_DEBOUNCE_MAX)
                        btn0_cnt <= btn0_cnt + 1'b1;
                    else
                        btn0_stable <= key0;
                end else begin
                    btn0_last <= key0;
                    btn0_cnt  <= 4'd0;
                end

                // key1 消抖
                if (key1 == btn1_last) begin
                    if (btn1_cnt < BTN_DEBOUNCE_MAX)
                        btn1_cnt <= btn1_cnt + 1'b1;
                    else
                        btn1_stable <= key1;
                end else begin
                    btn1_last <= key1;
                    btn1_cnt  <= 4'd0;
                end

                // 检测按下/释放事件
                if (btn0_stable == 1'b1 && key0 == 1'b0) begin
                    btn_code    <= 2'd0;
                    btn_pressed <= 1'b1;
                end else if (btn0_stable == 1'b0 && key0 == 1'b1) begin
                    btn_released <= 1'b1;
                end

                if (btn1_stable == 1'b1 && key1 == 1'b0) begin
                    btn_code    <= 2'd1;
                    btn_pressed <= 1'b1;
                end else if (btn1_stable == 1'b0 && key1 == 1'b1) begin
                    btn_released <= 1'b1;
                end
            end
        end
    end

endmodule