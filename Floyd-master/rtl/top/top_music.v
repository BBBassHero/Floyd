`include "parameters.vh"

module top_music (
    input  wire       sys_clk,
    input  wire       rst_n_in,
    output wire       led0,
    output wire       led1,
    output wire [3:0] key_row,
    input  wire [3:0] key_col,
    input  wire       key0,
    input  wire       key1,
    input  wire       enc_a,
    input  wire       enc_b,
    output wire       i2s_bclk,
    output wire       i2s_lrclk,
    output wire       i2s_data
);

    // ------------------------------------------------------------
    // 440 Hz @ 48 kHz, PHASE_WIDTH = 32
    // phase_step = 440 * 2^32 / 48000 ≈ 39370534
    // ------------------------------------------------------------
    localparam [31:0] DDS_TEST_440HZ_STEP = 32'd39370534;

    wire rst_n;
    wire sample_tick;
    wire key_scan_tick;

    // ------------------------------------------------------------
    // 复位同步
    // ------------------------------------------------------------
    reset_sync u_reset_sync (
        .clk       (sys_clk),
        .rst_n_in  (rst_n_in),
        .rst_n_out (rst_n)
    );

    // ------------------------------------------------------------
    // 时钟使能：48 kHz 采样脉冲 + 1 kHz 按键扫描脉冲
    // ------------------------------------------------------------
    clock_enable u_clock_enable (
        .clk           (sys_clk),
        .rst_n         (rst_n),
        .sample_tick   (sample_tick),
        .key_scan_tick (key_scan_tick)
    );

    // ------------------------------------------------------------
    // DDS 直连测试：固定 440 Hz 正弦波
    // 等 voice_engine / mixer / audio_pipeline 就绪后替换。
    // ------------------------------------------------------------
    wire signed [`FLOYD_AUDIO_WIDTH-1:0] dds_audio_sample;

    dds_oscillator #(
        .PHASE_WIDTH (`FLOYD_PHASE_WIDTH),
        .AUDIO_WIDTH (`FLOYD_AUDIO_WIDTH)
    ) u_dds_test (
        .clk             (sys_clk),
        .rst_n           (rst_n),
        .sample_tick     (sample_tick),
        .enable          (1'b1),
        .phase_step      (DDS_TEST_440HZ_STEP),
        .waveform_select (`FLOYD_WAVE_SINE),
        .audio_sample    (dds_audio_sample),
        .phase           ()
    );

    // ------------------------------------------------------------
    // I2S 接口：左右声道复制同一采样值
    // ------------------------------------------------------------
    wire signed [15:0] audio_left;
    wire signed [15:0] audio_right;
    wire               audio_valid;

    assign audio_left  = dds_audio_sample;
    assign audio_right = dds_audio_sample;
    assign audio_valid = sample_tick;

    i2s_tx u_i2s_tx (
        .clk         (sys_clk),
        .rst_n       (rst_n),
        .audio_left  (audio_left),
        .audio_right (audio_right),
        .audio_valid (audio_valid),
        .i2s_bclk    (i2s_bclk),
        .i2s_lrclk   (i2s_lrclk),
        .i2s_data    (i2s_data)
    );

    // ------------------------------------------------------------
    // 按键扫描：4x4 矩阵 + 板载 key0/key1
    // ------------------------------------------------------------
    wire [3:0] key_code;
    wire       key_pressed;
    wire       key_released;
    wire [1:0] btn_code;
    wire       btn_pressed;
    wire       btn_released;

    key_scan u_key_scan (
        .clk           (sys_clk),
        .rst_n         (rst_n),
        .key_scan_tick (key_scan_tick),
        .key_col       (key_col),
        .key_row       (key_row),
        .key0          (key0),
        .key1          (key1),
        .key_code      (key_code),
        .key_pressed   (key_pressed),
        .key_released  (key_released),
        .btn_code      (btn_code),
        .btn_pressed   (btn_pressed),
        .btn_released  (btn_released)
    );

    // ------------------------------------------------------------
    // 旋转编码器
    // ------------------------------------------------------------
    wire enc_step;
    wire enc_dir;

    encoder_decoder u_encoder (
        .clk      (sys_clk),
        .rst_n    (rst_n),
        .enc_a    (enc_a),
        .enc_b    (enc_b),
        .enc_step (enc_step),
        .enc_dir  (enc_dir)
    );

    // ------------------------------------------------------------
    // LED 状态
    // ------------------------------------------------------------
    wire key_activity = key_pressed | key_released | btn_pressed | btn_released;
    wire enc_activity = enc_step;

    led_status u_led_status (
        .clk          (sys_clk),
        .rst_n        (rst_n),
        .key_activity (key_activity),
        .enc_activity (enc_activity),
        .led0         (led0),
        .led1         (led1)
    );

    // ------------------------------------------------------------
    // 第三周临时观察信号：等 note_manager 接入后删除
    // ------------------------------------------------------------
    wire unused = ^{key_code, btn_code, enc_dir};

endmodule