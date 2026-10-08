# FPGA 实时多音色合成电子乐器开发手册

**目标平台：** Tang Mega 60K / GW5AT-LV60PG484A  
**项目方向：** 2026 高云半导体选题二  
**团队规模：** 3 人  
**建议周期：** 30 天  
**文档版本：** v1.0  
**日期：** 2026-09-19

---

## 1. 项目目标

构建一个基于 FPGA 的实时电子乐器。按键或触摸输入触发音符，编码器或第二类传感器控制音量、音色或颤音，FPGA 内部使用 DDS、波表、ADSR 和混音逻辑实时生成音频，再通过 I2S 输出到 DAC。

### 1.1 基础交付目标

- 两个独立可控的演奏交互维度。
- 至少 4 个独立声部同时发声，目标 8 声部。
- FPGA RTL 完成实时音频合成，不播放预录 PCM。
- 48 kHz、16 bit I2S 音频输出。
- 至少 2 种音色，目标 4 种基础波形。
- 每个声部独立相位累加器和 ADSR 包络。
- 控制到音频输出延迟不超过 10 ms，目标小于 6 ms。
- 测试模式能输出多路不同频率并观察独立谱峰。

### 1.2 拓展优先级

1. 编码器控制音量和音色切换。
2. 8 声部复音。
3. 双振荡器混合。
4. LFO 颤音或简单滑音。
5. 全局状态变量滤波器。
6. 简单延迟效果。
7. OLED/LED 状态反馈。
8. 16 声部或更高复音。

首月不把蓝牙、手机 App、复杂物理建模、32 声部、复杂混响设为硬性目标。

---

## 2. 系统架构

```text
按键/触摸/编码器
        │
        ▼
输入同步、扫描、消抖、事件检测
        │
        ▼
note_manager
        │
        ▼
voice_manager
        ├── voice0 ... voice7
        │       ├── DDS 振荡器
        │       ├── 波形 ROM
        │       ├── ADSR
        │       ├── LFO
        │       └── 声部音量
        ▼
audio_mixer → 可选滤波器/延迟 → i2s_tx → DAC/扬声器
```

### 2.1 设计原则

- 顶层只负责连接，不在 `top_music.v` 中堆叠算法。
- 每个声部独立保存音符、相位、包络和使能状态。
- 所有音频运算以统一的 `sample_tick` 更新。
- 参数集中定义，避免常数散落在多个模块。
- 优先使用定点数、查表、移位和流水线。
- 每个模块先仿真，再接入上层。

---

## 3. 三人分工

### 3.1 队员 A：音频合成核心

**工作内容：** DDS、波表、ADSR、单声部、混音、LFO、颤音、双振荡器和音频算法仿真。

**负责文件：**

```text
rtl/common/parameters.vh
rtl/voice/dds_oscillator.v
rtl/voice/waveform_rom.v
rtl/voice/adsr.v
rtl/voice/lfo.v
rtl/voice/voice_engine.v
rtl/audio/mixer.v
rtl/audio/audio_pipeline.v
sim/tb_dds_oscillator.v
sim/tb_adsr.v
sim/tb_voice_engine.v
sim/tb_mixer.v
rom/*.hex
scripts/gen_wave_rom.py
```

**验收标准：** DDS 输出 440 Hz；ADSR 五状态正常；4 声部混音不溢出；至少实现正弦波和方波。

### 3.2 队员 B：时钟、输入和板级接口

**工作内容：** Gowin 工程、时钟、PLL、复位、按键、触摸、编码器、I2S、约束、下载和 DAC 联调。

**负责文件：**

```text
rtl/top/top_music.v
rtl/common/reset_sync.v
rtl/common/clock_enable.v
rtl/control/key_scan.v
rtl/control/encoder_decoder.v
rtl/audio/i2s_tx.v
rtl/display/led_status.v
constraints/tang_mega60k.cst
gowin/TangMega60K_Music.gprj
sim/tb_i2s_tx.v
sim/tb_top_music.v
docs/pin_assignment.md
```

**验收标准：** Gowin 工程能生成下载文件；LED、复位和时钟通过；I2S 固定测试音输出；按键和编码器事件稳定。

### 3.3 队员 C：系统集成、测试和文档

**工作内容：** 顶层集成、`note_manager`、`voice_manager`、系统 Testbench、延迟/频率/复音测试、资源报告、技术报告、PPT 和视频。

**负责文件：**

```text
rtl/control/note_manager.v
rtl/control/voice_manager.v
rtl/effects/filter_svf.v
rtl/effects/delay_effect.v
rtl/display/oled_ctrl.v
sim/tb_top_music.v
docs/system_architecture.md
docs/module_interfaces.md
docs/verification_plan.md
docs/development_log.md
README.md
```

### 3.4 分工规则

- 每个人拥有明确目录，避免同时修改同一文件。
- 顶层文件由队员 B 维护，接口修改必须通知全队。
- 参数文件由队员 A 维护，修改后必须更新接口文档。
- 队员 C 每天从三个分支集成一次稳定版本。
- 任何接口变更必须先更新 `docs/module_interfaces.md`。

---

## 4. 工程目录和开发优先级

```text
fpga_music_engine/
├── README.md
├── gowin/TangMega60K_Music.gprj
├── rtl/top/top_music.v
├── rtl/common/{parameters.vh,reset_sync.v,clock_enable.v}
├── rtl/control/{key_scan.v,encoder_decoder.v,note_manager.v,voice_manager.v}
├── rtl/voice/{dds_oscillator.v,waveform_rom.v,adsr.v,lfo.v,voice_engine.v}
├── rtl/audio/{mixer.v,audio_pipeline.v,i2s_tx.v}
├── rtl/effects/{filter_svf.v,delay_effect.v}
├── rtl/display/{led_status.v,oled_ctrl.v}
├── sim/
├── constraints/tang_mega60k.cst
├── rom/{sine.hex,triangle.hex,saw.hex,square.hex}
└── docs/ 和 scripts/
```

### 第一批：最小可测试闭环

```text
parameters.vh → waveform_rom.v → dds_oscillator.v
→ i2s_tx.v → audio_pipeline.v → top_music.v
→ tb_dds_oscillator.v / tb_i2s_tx.v / tb_top_music.v
```

目标：固定产生 A4=440 Hz，通过 I2S 输出；暂时不接按键、不接 OLED、不做多声部。

### 第二批：单声部和四声部

```text
adsr.v → voice_engine.v → mixer.v
→ tb_adsr.v / tb_voice_engine.v / tb_mixer.v
```

目标：一个声部可以按下、保持、释放，四个声部可以同时混音。

### 第三批：交互和声部管理

```text
key_scan.v → note_manager.v → voice_manager.v → encoder_decoder.v
```

目标：按键触发真实音符，编码器调节音量或切换音色。

### 第四批：拓展

```text
lfo.v、filter_svf.v、delay_effect.v、oled_ctrl.v
```

这些功能不能阻塞基础版本交付。

---

## 5. 四周开发计划

### 第 1 周：环境和单音链路

**队员 A：** 学习定点数，生成正弦波 ROM，完成 DDS 和 440 Hz 仿真。  
**队员 B：** 安装 Gowin IDE/Programmer，创建 Tang Mega 60K 工程，完成 LED、时钟、复位和 I2S 框架。  
**队员 C：** 建立 Git 分支、系统框图、Testbench 模板和每日测试记录。

**周末必须通过：** DDS 频率正确；I2S 有波形；工程可综合；复位后静音。

### 第 2 周：ADSR 和四声部

**队员 A：** 完成 ADSR、单声部、音量缩放、方波和三角波。  
**队员 B：** 完成 I2S 数据对齐，输出固定测试音，确认 DAC 或板载音频路径。  
**队员 C：** 完成 ADSR Testbench、四声部场景和混音溢出检查。

**周末必须通过：** ADSR 正常；四声部同时运行；I2S 数据与混音数据一致。

### 第 3 周：交互和声部管理

**队员 A：** 扩展 8 声部，加入第二振荡器和 LFO 颤音。  
**队员 B：** 完成按键扫描、消抖、编码器解码和 LED 状态显示。  
**队员 C：** 完成音符到频率控制字转换、空闲声部分配、声部替换和快速按键测试。

**周末必须通过：** 按键触发不同音符；4～8 个按键同时触发稳定；编码器改变音量或音色。

### 第 4 周：指标和答辩

**队员 A：** 优化混音和包络，制作四频率测试模式，视资源加入滤波或延迟。  
**队员 B：** 完成 DAC 联调，测量 I2S、延迟、资源和时序。  
**队员 C：** 整理测试证据、技术报告、答辩 PPT 和 3 分钟演示脚本。

**第 30 天：** 只修复阻塞性错误，不再新增大功能，备份工程和烧录文件。

---

## 6. 零基础学习内容

### 6.1 数字电路

二进制、补码、组合/时序逻辑、D 触发器、寄存器、计数器、复位、状态机、RAM、ROM、FIFO、时钟和时钟使能。

练习顺序：

```text
LED 闪烁 → 计数器 → 按键消抖 → 状态机 → ROM 查表 → PWM → DDS
```

### 6.2 Verilog

必须掌握：

- `module`、端口和参数。
- `wire`、`reg`、`logic`。
- `assign` 和组合/时序 `always`。
- `if`、`case`、位宽、符号、拼接、移位。
- 阻塞赋值与非阻塞赋值。
- 参数化模块、`generate` 和 Testbench。

重点避免：

- 组合逻辑漏分支产生锁存器。
- 位宽不匹配导致截断。
- 有符号和无符号混用。
- 未仿真就直接下载。
- 随意生成派生时钟。

### 6.3 音频与 DSP

必须掌握：采样率、奈奎斯特频率、定点数、量化、波表、相位累加器、ADSR、混音、削波、LFO、I2S 和延迟线。

```text
phase_step = frequency × 2^PHASE_WIDTH / sample_rate
```

### 6.4 FPGA 工程

学习创建工程、选择芯片、编写约束、综合、布局布线、下载、读取资源/时序报告、使用逻辑分析仪。

### 6.5 全员学习要求

每个人都必须能读懂和修改 DDS、ADSR、I2S、混音、声部管理和 Testbench，不能让关键知识只掌握在一个人手里。

---

## 7. 软件清单

### 必需软件

- **Gowin EDA / Gowin IDE：** 工程创建、综合、布局布线、生成烧录文件、资源与时序报告。
- **Gowin Programmer：** JTAG 下载和重新配置 FPGA。
- **Visual Studio Code：** Verilog、Markdown 和脚本编辑。
- **Git：** 分支、版本、回退和多人协作。

### 仿真和分析

- Icarus Verilog 或 Gowin 配套仿真工具。
- Verilator，用于快速 lint 和可选的 C++ 仿真。
- GTKWave，用于查看 VCD/FST 波形。
- Python 3、NumPy、Matplotlib，用于波表、波形和频谱分析。
- Audacity，可选，用于查看生成的音频文件。

---

## 8. 硬件清单

### 必需硬件

- Tang Mega 60K 开发板。
- USB 数据线。
- JTAG 下载方式所需的线材或下载器。
- I2S DAC，或已确认的板载音频输出链路。
- 8 个按键或 4×4 按键矩阵。
- 旋转编码器。
- 杜邦线、排针、面包板。
- 耳机或小功放音箱。

### 建议硬件

- 逻辑分析仪。
- 示波器。
- 万用表。
- OLED 模块。
- 备用 I2S DAC。
- 3.3 V 稳压/电平转换模块。
- 电容触摸、光敏或压力传感器。

### 电气要求

- FPGA GPIO 外接信号优先使用 3.3 V 逻辑。
- 不把 5 V 信号直接接入 FPGA GPIO。
- DAC、输入模块和 FPGA 共地。
- 上电前检查 VCC、GND、信号方向和引脚复用。
- 约束文件必须来自对应 Tang Mega 60K 版本。

---

## 9. 关键模块规范

### `parameters.vh`

统一定义 `SYS_CLK_FREQ`、`AUDIO_SAMPLE_RATE`、`AUDIO_WIDTH`、`PHASE_WIDTH`、`WAVE_ADDR_WIDTH`、`VOICE_COUNT` 和 `KEY_COUNT`。

建议第一版：

```text
AUDIO_SAMPLE_RATE = 48000
AUDIO_WIDTH      = 16
PHASE_WIDTH      = 32
WAVE_ADDR_WIDTH  = 10
VOICE_COUNT      = 4 或 8
```

### `dds_oscillator.v`

输入：`clk`、`rst_n`、`sample_tick`、`phase_step`、`waveform_select`、`enable`。  
输出：`audio_sample`、`phase`。

要求：相位连续、复位确定、只在采样使能时更新、波表地址使用相位高位、输出为明确有符号定点数据。

### `adsr.v`

状态：

```text
IDLE → ATTACK → DECAY → SUSTAIN → RELEASE → IDLE
```

`note_on` 进入 Attack，`note_off` 进入 Release，Release 结束后发出 `voice_finished`，快速重新触发不能锁死。

### `voice_manager.v`

1. 优先空闲声部。
2. 无空闲声部时替换最早触发声部。
3. `note_off` 只释放匹配音符。
4. ADSR Release 完成后回收声部。
5. 保存 `voice_active`、`voice_note`、`voice_age`。

### `mixer.v`

```text
单声部：16 位
4 声部混音：至少 18 位
8 声部混音：至少 20 位
输出前：缩放 + 饱和截断到 16 位
```

### `i2s_tx.v`

第一版固定为标准 I2S、16 bit、48 kHz、左右声道复制同一采样值。必须验证 BCLK、LRCLK、DATA 频率、边沿、对齐和左右声道顺序。

---

## 10. 仿真与验收

### 单元测试

**DDS：** 440 Hz 正确、相位连续、波形选择有效、复位确定。  
**ADSR：** 五状态可达、时间可调、Release 归零、快速触发正常。  
**混音：** 4/8 声部叠加、正负溢出处理、全静音输出零。  
**I2S：** 复位静音、固定数据正确、左右声道正确、无明显丢样。

### 系统测试

- 单键演奏。
- 四键和弦。
- 快速连续按键。
- 声部全部占满。
- 快速切换音色。
- 编码器正反转。
- 复位时按键。
- 30 分钟连续运行。

### 多频率测试模式

固定输出：

```text
440 Hz、550 Hz、660 Hz、770 Hz
```

通过频谱仪、电脑声卡或示波器观察多个谱峰。

### 延迟测试

```text
输入触发 → 同步 → 消抖 → 声部更新 → DDS → I2S → DAC
```

记录测试设备、典型延迟、最大延迟、测试次数和测试条件。

---

## 11. 版本管理和日常工作流

### 分支

```text
main       稳定版本
dev-audio  队员 A
dev-io     队员 B
dev-test   队员 C
```

### 提交格式

```text
feat: add single voice DDS
feat: add ADSR envelope
fix: correct I2S alignment
fix: prevent mixer overflow
test: add four voice testbench
docs: update verification plan
```

### 每日流程

```text
拉取稳定版本
→ 开发一个小功能
→ 编写/更新 Testbench
→ 仿真
→ lint 或综合
→ 记录结果
→ 提交分支
→ 通知队员 C 集成
```

进入 `main` 前必须满足：接口已记录、正常路径和边界路径有测试、没有未解释的关键警告、综合无关键错误、另一名队员完成代码阅读。

---

## 12. 风险处理

### I2S 不发声

检查电源和共地 → 检查 BCLK/LRCLK/DATA → 逻辑分析仪观察 → 先输出全零 → 再输出固定方波 → 最后接入 DDS。

### 按键不稳定

确认输入极性和电平 → 两级同步 → 消抖计数器 → 检查按下/释放脉冲 → 再接声部管理器。

### 音频爆音

检查 ADSR → 增加音量平滑 → 增大混音位宽 → 检查相位连续性 → 检查 I2S 数据对齐。

### 资源或时序不足

降为 4 声部定位 → 波表映射 BRAM → 移位替代常数乘法 → 增加流水线 → 暂时移除滤波和效果器。

---

## 13. 最终交付清单

### 工程

- Gowin 工程。
- RTL 源码。
- Testbench。
- 约束文件。
- 波表 ROM。
- 可下载 bitstream。
- 稳定版本标签。

### 测试证据

- DDS 波形。
- ADSR 波形。
- 4 声部混音波形。
- I2S 时序截图。
- 多频率频谱截图。
- 延迟测量记录。
- 资源报告。
- 时序报告。

### 文档

- 系统框图。
- 模块接口说明。
- 关键算法说明。
- 硬件连接图。
- 引脚约束表。
- 使用说明。
- 故障排查说明。
- 技术报告。
- 答辩 PPT。
- 演示视频。

---

## 14. 第一周立即执行清单

### 队员 A

- [ ] 完成参数表。
- [ ] 确定定点格式。
- [ ] 生成正弦波 ROM。
- [ ] 完成 DDS 接口。
- [ ] 仿真 440 Hz。

### 队员 B

- [ ] 安装 Gowin IDE 和 Programmer。
- [ ] 创建 Tang Mega 60K 工程。
- [ ] 确认芯片、时钟和下载方式。
- [ ] 完成 LED 闪烁。
- [ ] 确认 I2S/DAC 路径。

### 队员 C

- [ ] 建立 Git 分支。
- [ ] 完成系统框图。
- [ ] 完成模块接口表。
- [ ] 建立测试记录。
- [ ] 建立每日集成流程。

### 全队

- [ ] 确认按键或触摸方案。
- [ ] 确认编码器方案。
- [ ] 确认 DAC 或板载音频链路。
- [ ] 确认每天固定集成时间。

---

## 16. 三人接口约定

本节是三人协作的强制约定。任何模块只有满足本节要求，才允许接入 `main` 分支。

### 16.1 文件所有权

| 模块 | 第一负责人 | 第二审核人 | 允许直接修改的人 |
|---|---|---|---|
| `parameters.vh` | 队员 A | 队员 C | A，其他人需先沟通 |
| `top_music.v` | 队员 B | 队员 C | B，其他人提交接口申请 |
| `dds_oscillator.v`、`adsr.v`、`voice_engine.v` | 队员 A | 队员 C | A |
| `i2s_tx.v`、`key_scan.v`、`encoder_decoder.v` | 队员 B | 队员 A | B |
| `note_manager.v`、`voice_manager.v` | 队员 C | 队员 A | C |
| `mixer.v`、`audio_pipeline.v` | 队员 A | 队员 B | A |
| `filter_svf.v`、`delay_effect.v`、`oled_ctrl.v` | 队员 C | 队员 B | C |
| `sim/` 测试文件 | 队员 C | 对应模块负责人 | C 或模块负责人 |
| `constraints/tang_mega60k.cst` | 队员 B | 全队 | B |
| `docs/` | 队员 C | 全队 | C |

### 16.2 通用端口命名

所有 RTL 模块统一使用以下命名：

```verilog
clk           // 主时钟
rst_n         // 低有效复位
sample_tick   // 音频采样更新脉冲
enable        // 模块使能
valid         // 当前数据有效
ready         // 模块可以接收数据
data          // 数据总线
```

命名规则：

- 低有效信号以 `_n` 结尾。
- 单周期事件以 `_pulse`、`_event` 或 `_tick` 结尾。
- 按键按下事件使用 `key_pressed`，释放事件使用 `key_released`。
- 音频采样使用 `audio_sample`，不要使用含义不明确的 `data1`、`tmp`。
- 参数输入使用 `*_cfg` 或 `*_param`。
- 状态输出使用 `*_state`，使能输出使用 `*_active` 或 `*_valid`。

### 16.3 时钟和复位约定

第一版只允许使用以下两类时序控制：

```text
系统主时钟 clk
系统主时钟 + sample_tick 时钟使能
```

禁止在普通 RTL 中自行生成新的逻辑时钟。I2S 的 BCLK 和 LRCLK 作为输出时序信号生成，但不能反过来驱动核心逻辑。

复位约定：

- 外部复位统一进入 `reset_sync.v`。
- 核心模块只接收同步后的 `rst_n`。
- 复位后音频输出必须为零。
- 复位后 `voice_active`、`note_on`、`note_off`、`i2s_busy` 必须为确定值。

### 16.4 音频采样约定

```text
采样率：48 kHz
音频位宽：16 bit
数据类型：二进制补码有符号数
更新时机：sample_tick 上升有效时
静音值：16'sd0
```

音频模块之间的采样接口统一为：

```verilog
input  wire        sample_tick;
input  wire        sample_valid;
input  wire signed [AUDIO_WIDTH-1:0] audio_in;
output reg  signed [AUDIO_WIDTH-1:0] audio_out;
```

如果模块内部使用更宽位宽，必须在模块内部完成扩展，在输出端明确截断或饱和，不允许由上层猜测位宽。

### 16.5 演奏事件约定

`note_manager` 输出事件，`voice_manager` 接收事件。事件不得直接从按键扫描模块连接到声部模块。

建议接口：

```verilog
note_event_valid
note_event_on
note_event_off
[6:0] note_number
[7:0] note_velocity
```

语义约定：

- `note_event_valid=1` 表示当前周期有一个有效事件。
- `note_event_on=1` 表示按下或触发。
- `note_event_off=1` 表示释放。
- `note_event_on` 与 `note_event_off` 不得同时为 1。
- `note_number` 使用 MIDI 风格编号，C4 建议使用 60。
- 第一版没有真实力度输入时，`note_velocity` 固定为 `8'hFF`。
- 事件默认只保持一个系统时钟周期。

### 16.6 声部管理约定

`voice_manager` 负责分配声部，`voice_engine` 只负责处理被分配后的单个声部，不参与全局声部选择。

每个声部至少包含：

```verilog
voice_active
voice_note
voice_velocity
voice_age
voice_note_on
voice_note_off
voice_finished
```

分配规则：

1. 优先分配 `voice_active=0` 的声部。
2. 没有空闲声部时替换 `voice_age` 最小的声部。
3. `voice_finished=1` 后，声部可以回到空闲状态。
4. `voice_manager` 不直接修改 ADSR 内部状态，只发送 `note_on` 和 `note_off`。

### 16.7 参数总线约定

第一版不建立复杂 AXI 或 Wishbone 总线，使用明确的静态参数端口：

```verilog
[2:0] tone_select
[7:0] master_volume
[7:0] osc1_volume
[7:0] osc2_volume
[7:0] attack_rate
[7:0] decay_rate
[7:0] sustain_level
[7:0] release_rate
[7:0] lfo_depth
```

参数要求：

- 范围在 `parameters.vh` 或接口文档中定义。
- 旋钮或编码器输入先转换为稳定的寄存器值，再连接到音频模块。
- 音量、频率和滤波参数变化需要平滑处理。
- 不在音频模块内部读取按键或编码器物理信号。

### 16.8 I2S 接口约定

`audio_pipeline` 只输出已经准备好的左右声道采样，`i2s_tx` 只负责串行发送。

```verilog
input  wire signed [15:0] audio_left
input  wire signed [15:0] audio_right
input  wire               audio_valid
output wire               i2s_bclk
output wire               i2s_lrclk
output wire               i2s_data
```

约定：

- I2S 发送模块不实现 DDS、ADSR 或混音。
- 音频数据在 `audio_valid=1` 时被采样。
- 第一版左右声道发送相同数据。
- 无有效数据时发送零值，不发送未初始化数据。
- I2S 时序修改必须同时更新 `tb_i2s_tx.v` 和接口文档。

### 16.9 Testbench 约定

每个功能模块必须有独立 Testbench，至少包含：

```text
时钟
复位
正常输入
边界输入
异常输入
检查条件
结束条件
```

Testbench 命名必须与模块一致：

```text
dds_oscillator.v      → tb_dds_oscillator.v
voice_engine.v        → tb_voice_engine.v
i2s_tx.v              → tb_i2s_tx.v
```

测试记录必须包含：

- 仿真时间。
- 使用的参数。
- 通过项。
- 失败项。
- 波形文件或截图路径。

### 16.10 接口变更流程

任何人需要修改端口、位宽、有效电平或时序时，必须按以下流程：

1. 在 `docs/module_interfaces.md` 写出变更原因。
2. 通知受影响模块负责人。
3. 修改对应 Testbench。
4. 在个人分支完成仿真。
5. 由另一名队员审核。
6. 由队员 C 集成到 `main`。

不得直接在队友分支中修改接口文件。

### 16.11 联调交接清单

模块交给其他队员前，必须提供：

- 模块文件。
- 端口表。
- 参数范围。
- 时钟和复位要求。
- 一个最小 Testbench。
- 已知限制。
- 当前仿真截图或日志。

交接说明模板：

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

### 16.12 冲突处理原则

出现接口争议时，按以下优先级处理：

1. 赛题硬性要求。
2. 已经通过的 Testbench。
3. 已经验证的硬件时序。
4. 模块可扩展性。
5. 代码简洁性。

如果无法当天达成一致，保留当前稳定接口，新增方案放入个人分支验证，不直接破坏 `main`。

