# 四声部音频链路交接说明

## 1. 交接状态

| 项目 | 内容 |
|---|---|
| 负责人 | 成员 A |
| 接收方 | 成员 C：声部管理和顶层集成；成员 B：I2S/DAC 接口 |
| 状态 | 可接入联调 |
| 音频格式 | 48 kHz，16 bit，有符号二进制补码 |
| 声部数量 | 4 |
| 交接日期 | 2026-10-11 |

## 2. 已交付文件

```text
rtl/common/parameters.vh
rtl/voice/waveform_rom.v
rtl/voice/dds_oscillator.v
rtl/voice/adsr.v
rtl/voice/voice_engine.v
rtl/audio/mixer.v
rtl/audio/audio_pipeline.v
sim/tb_adsr.v
sim/tb_voice_engine.v
sim/tb_mixer.v
sim/tb_audio_pipeline.v
rom/sine.hex
rom/square.hex
rom/triangle.hex
```

`audio_pipeline.v` 实例化 4 个独立的 `voice_engine`，并将四路采样连接到 `mixer.v`。声部分配、音符到 `phase_step` 的换算、按键和编码器均不在本模块内完成。

## 3. 时钟和复位

| 信号 | 要求 |
|---|---|
| `clk` | 所有音频模块使用同一个主时钟 |
| `rst_n` | 低有效，同步到 `clk`；拉低时所有声部静音并回到空闲 |
| `sample_tick` | 每个音频采样周期产生一个 `clk` 周期的脉冲；当前目标为 48 kHz |

`note_on` 和 `note_off` 事件应保持一个主时钟周期。事件不应在同一个声部上同时有效；如果同时有效，当前 `adsr.v` 的 `note_on` 优先级更高。

## 4. `audio_pipeline` 端口约定

### 公共输入

| 端口 | 位宽 | 说明 |
|---|---:|---|
| `clk` | 1 | 主时钟 |
| `rst_n` | 1 | 低有效同步复位 |
| `sample_tick` | 1 | 音频采样更新脉冲 |
| `attack_rate` | `RATE_WIDTH` | ADSR Attack 更新间隔，0 按 1 处理 |
| `decay_rate` | `RATE_WIDTH` | ADSR Decay 更新间隔，0 按 1 处理 |
| `sustain_level` | `ENVELOPE_WIDTH` | Sustain 电平，0 到最大值 |
| `release_rate` | `RATE_WIDTH` | ADSR Release 更新间隔，0 按 1 处理 |

### 每个声部的输入

将下表中的 `N` 替换为 `0`、`1`、`2` 或 `3`：

| 端口 | 位宽 | 说明 |
|---|---:|---|
| `voiceN_note_on` | 1 | 触发第 N 个声部 |
| `voiceN_note_off` | 1 | 释放第 N 个声部 |
| `voiceN_note` | 7 | MIDI 音符编号；当前由上层保存，音高实际由 `phase_step` 决定 |
| `voiceN_velocity` | 8 | 力度接口；当前 `voice_engine` 保留该接口，实际音量由 `voiceN_volume` 决定 |
| `voiceN_phase_step` | `PHASE_WIDTH` | DDS 相位步进，决定声部频率 |
| `voiceN_waveform_select` | 3 | `0` 正弦，`1` 方波，`2` 三角波 |
| `voiceN_volume` | 8 | Q0.8 声部音量；`0` 静音，`128` 约半音量，`255` 满音量 |

### 每个声部的输出

| 端口 | 位宽 | 说明 |
|---|---:|---|
| `voiceN_active` | 1 | 声部处于 Attack、Decay、Sustain 或 Release 时为 1 |
| `voiceN_finished` | 1 | Release 结束时输出一个主时钟周期的脉冲 |

### 混音输出

| 端口 | 位宽 | 说明 |
|---|---:|---|
| `mixed_sample` | signed `AUDIO_WIDTH` | 四声部混音后的当前采样值，直接接音频管线或 I2S 左右声道 |

## 5. 混音行为

`mixer.v` 的计算关系为：

```text
mix_sum     = voice_sample_0 + voice_sample_1
            + voice_sample_2 + voice_sample_3
mixed_sample = saturate(mix_sum >>> 2)
```

- 四路输入均为 16 位有符号二进制补码。
- 内部累加器为 18 位。
- 输出右移 2 位，相当于固定除以 4，避免四个满幅同相声部相加溢出。
- 输出超出 16 位范围时饱和到 `32767` 或 `-32768`。
- 四路全为零时，`mixed_sample` 为零。
- 当前设计是固定四分之一缩放：只有一个声部有效时，其输出也会按四分之一缩放。若后续需要按活动声部数量自动归一化，应由成员 A 另行修改接口和测试。

## 6. 成员 C 接入要求

成员 C 的 `voice_manager` 应为每个声部提供：

1. 单周期 `voiceN_note_on` 和 `voiceN_note_off` 脉冲。
2. 保存后的 `voiceN_note`、`voiceN_velocity`。
3. 音符对应的 `voiceN_phase_step`。
4. 当前音色对应的 `voiceN_waveform_select`。
5. 当前声部音量 `voiceN_volume`。
6. 根据 `voiceN_finished` 回收已经完成 Release 的声部。

`voice_manager` 不应直接修改 DDS 相位或包络状态，只驱动 `audio_pipeline` 的端口。

## 7. 成员 B 接入要求

成员 B 将 `mixed_sample` 接到 I2S 音频数据路径：

```verilog
assign audio_left  = mixed_sample;
assign audio_right = mixed_sample;
```

若 `i2s_tx` 使用 `audio_valid`，应在每个新的 `sample_tick` 后采集一次 `mixed_sample`。I2S 模块只负责串行发送，不应重复实现混音、DDS 或 ADSR。

## 8. 已完成验证

在 `Floyd` 目录执行：

```powershell
iverilog -g2012 -I rtl/common -o sim/tb_mixer.vvp `
  rtl/audio/mixer.v sim/tb_mixer.v
vvp sim/tb_mixer.vvp
```

结果：

```text
PASS: four-voice mixer scaling, saturation, and mute checks passed
```

四声部链路测试：

```powershell
iverilog -g2012 -I rtl/common -o sim/tb_audio_pipeline.vvp `
  rtl/voice/waveform_rom.v rtl/voice/dds_oscillator.v rtl/voice/adsr.v `
  rtl/voice/voice_engine.v rtl/audio/mixer.v rtl/audio/audio_pipeline.v `
  sim/tb_audio_pipeline.v
vvp sim/tb_audio_pipeline.vvp
```

结果：

```text
PASS: four voice pipeline activation, mixing, and release checks passed
```

测试覆盖：四路同时 `note_on`、混音输出非零、四路同时 `note_off`、Release 完成、最终回到静音。

## 9. 已知限制和联调注意事项

- `audio_pipeline` 当前没有 `audio_valid` 输出；采样有效时序由外部 `sample_tick` 统一管理。
- `voice_note` 和 `voice_velocity` 已保留在接口中，但当前音高和音量分别由 `phase_step` 和 `voice_volume` 实际控制。
- `sample_tick` 必须来自稳定的时钟使能，不能在模块内部生成新的逻辑时钟。
- `rom/*.hex` 路径按工程根目录解析；综合工具中需要将 ROM 文件加入工程或设置等效路径。
- 当前只实现 4 声部，不应直接按 8 声部连接；扩展 8 声部时需要同步增加 mixer 位宽和验证用例。

## 10. 交接后的下一步

- 成员 C：将 `voice_manager` 的四组状态和事件接入 `audio_pipeline`，完成真实音符分配测试。
- 成员 B：将 `mixed_sample` 接入 I2S，验证 48 kHz 采样、左右声道和 DAC 输出。
- 成员 A：配合解决联调中的位宽、时序或音量问题；基础链路稳定后再实现 LFO 和第二振荡器。
