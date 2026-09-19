# 三人模块接口约定

## 1. 通用时序

```text
主时钟：clk
复位：rst_n，低有效，同步到主时钟域
音频采样使能：sample_tick，每个音频采样周期产生一个时钟周期脉冲
```

核心模块只使用 `clk` 和 `sample_tick`，禁止使用普通逻辑生成新的内部时钟。

## 2. 音频数据格式

```text
采样率：48 kHz
采样位宽：16 bit
编码：二进制补码有符号数
静音：16'sd0
左右声道：第一版发送相同采样值
```

模块内部可以使用更宽位宽，但输出前必须明确做缩放、饱和或截断。

## 3. 模块边界

```text
key_scan
    → note_manager
    → voice_manager
    → voice_engine[0:N-1]
    → mixer
    → audio_pipeline
    → i2s_tx
```

约定：

- `key_scan` 只处理物理输入，不生成频率。
- `note_manager` 只负责音符编号和事件，不分配声部。
- `voice_manager` 只负责声部占用和回收，不实现音频算法。
- `voice_engine` 只处理一个声部。
- `mixer` 只做多声部叠加、缩放和饱和。
- `audio_pipeline` 只负责音频链路连接和可选效果。
- `i2s_tx` 只负责串行发送，不实现合成算法。

## 4. 演奏事件接口

```verilog
note_event_valid
note_event_on
note_event_off
[6:0] note_number
[7:0] note_velocity
```

语义：

- `note_event_valid=1` 表示当前周期有一个有效事件。
- `note_event_on` 和 `note_event_off` 不得同时为 1。
- `note_number` 使用 MIDI 风格编号，C4 使用 60。
- 第一版无力度传感器时，`note_velocity=8'hFF`。
- 事件默认只保持一个主时钟周期。

## 5. 声部接口

每个 `voice_engine` 至少接收：

```verilog
voice_note_on
voice_note_off
[6:0] voice_note
[7:0] voice_velocity
[31:0] phase_step
[2:0] waveform_select
[7:0] voice_volume
```

每个 `voice_engine` 至少输出：

```verilog
voice_active
voice_finished
signed [15:0] voice_sample
```

`voice_manager` 负责生成 `voice_note_on` 和 `voice_note_off`，`voice_engine` 不直接读取按键。

## 6. 参数约定

全局参数集中放在 `rtl/common/parameters.vh`：

```text
SYS_CLK_FREQ
AUDIO_SAMPLE_RATE
AUDIO_WIDTH
PHASE_WIDTH
WAVE_ADDR_WIDTH
VOICE_COUNT
KEY_COUNT
```

参数变化必须同步检查：

- 波表地址位宽。
- 音频采样使能计数。
- I2S 分频。
- 混音内部位宽。
- Testbench 的时间和期望值。

## 7. I2S 接口

```verilog
input  wire signed [15:0] audio_left
input  wire signed [15:0] audio_right
input  wire               audio_valid
output wire               i2s_bclk
output wire               i2s_lrclk
output wire               i2s_data
```

`audio_valid` 有效时，`i2s_tx` 采集新的左右声道数据；无效时发送零值。I2S 时序调整时必须同步更新 `sim/tb_i2s_tx.v`。

## 8. 文件所有权

| 文件类型 | 负责人 | 审核人 |
|---|---|---|
| DDS、ADSR、声部音频 | 队员 A | 队员 C |
| 顶层、时钟、输入、I2S、约束 | 队员 B | 队员 A |
| 声部管理、测试、文档、集成 | 队员 C | 队员 A/B |
| 参数文件 | 队员 A | 队员 C |
| `top_music.v` | 队员 B | 队员 C |
| `main` 分支 | 队员 C 维护 | 全队审核 |

## 9. 接口变更流程

1. 在本文档记录变更原因。
2. 通知受影响模块负责人。
3. 修改相应 Testbench。
4. 在个人分支仿真和综合。
5. 由另一名队员审核。
6. 队员 C 合并到 `main`。

禁止直接修改队友分支中的端口和位宽。

## 10. 模块交接模板

```text
模块名称：
负责人：
输入时钟：
复位方式：
输入端口：
输出端口：
数据位宽：
有效时机：
已完成测试：
未解决问题：
下一步建议：
```

