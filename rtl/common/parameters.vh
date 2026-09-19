`ifndef FLOYD_PARAMETERS_VH
`define FLOYD_PARAMETERS_VH

// Floyd audio-engine compile-time parameters.
// The board clock is intentionally configurable until the final Tang Mega
// 60K constraint file is confirmed.
`define FLOYD_SYS_CLK_HZ             50000000
`define FLOYD_AUDIO_SAMPLE_RATE_HZ   48000
`define FLOYD_AUDIO_WIDTH            16
`define FLOYD_PHASE_WIDTH            32
`define FLOYD_WAVE_TABLE_DEPTH       1024
`define FLOYD_WAVE_ADDR_WIDTH        10
`define FLOYD_SINE_ROM_FILE          "rom/sine.hex"

`endif
