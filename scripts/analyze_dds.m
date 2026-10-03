% Floyd DDS output analysis.
% Run this script from the Floyd project root after HDL simulation.

clear;
close all;
clc;

project_root = fileparts(fileparts(mfilename("fullpath")));
sample_file = fullfile(project_root, "simulation_outputs", "dds_samples.txt");
rom_dir = fullfile(project_root, "rom");
sys_clk_hz = 50e6;
sample_div = 1042;
target_hz = 440;

x = load(sample_file);
x = x(:);
if isempty(x)
    error("No samples found in %s", sample_file);
end

% The testbench uses integer clock division, so use the actual sample rate.
fs = sys_clk_hz / sample_div;
x = x - mean(x);
N = length(x);
t = (0:N-1).' / fs;

figure("Name", "Floyd DDS waveform");
plot(t, x, "LineWidth", 1.0);
grid on;
xlabel("Time (s)");
ylabel("Amplitude");
title(sprintf("DDS output: %d samples, fs = %.6f Hz", N, fs));

% A Hann window reduces spectral leakage.
w = hann(N);
x_windowed = x .* w;
nfft = 2^nextpow2(N);
X = abs(fft(x_windowed, nfft));
f = (0:nfft-1).' * fs / nfft;

half = 1:floor(nfft / 2);
[~, peak_index] = max(X(half));
peak_index = half(peak_index);
peak_hz = f(peak_index);

% Three-bin parabolic interpolation improves the peak estimate.
if peak_index > 1 && peak_index < nfft
    alpha = X(peak_index - 1);
    beta = X(peak_index);
    gamma = X(peak_index + 1);
    denominator = alpha - 2 * beta + gamma;
    if denominator ~= 0
        delta = 0.5 * (alpha - gamma) / denominator;
        interpolated_hz = (peak_index - 1 + delta) * fs / nfft;
    else
        interpolated_hz = peak_hz;
    end
else
    interpolated_hz = peak_hz;
end

figure("Name", "Floyd DDS spectrum");
plot(f(half), X(half), "LineWidth", 1.0);
grid on;
xlabel("Frequency (Hz)");
ylabel("Magnitude");
title(sprintf("DDS spectrum, FFT resolution = %.6f Hz", fs / nfft));
xlim([max(0, target_hz - 150), target_hz + 150]);

fprintf("Samples                 : %d\n", N);
fprintf("Actual sample rate      : %.9f Hz\n", fs);
fprintf("FFT bin resolution      : %.9f Hz\n", fs / nfft);
fprintf("Raw FFT peak            : %.6f Hz\n", peak_hz);
fprintf("Interpolated peak       : %.6f Hz\n", interpolated_hz);
fprintf("Target frequency        : %.6f Hz\n", target_hz);
fprintf("Interpolated error      : %.6f Hz\n", interpolated_hz - target_hz);

% -------------------------------------------------------------------------
% Waveform ROM verification: sine, square, and triangle use the same
% phase-addressed format and are analyzed with the same time/spectrum flow.
% -------------------------------------------------------------------------
waveform_names = ["Sine", "Square", "Triangle"];
rom_files = ["sine.hex", "square.hex", "triangle.hex"];
rom_data = cell(1, numel(rom_files));

for k = 1:numel(rom_files)
    rom_path = fullfile(rom_dir, rom_files(k));
    if ~isfile(rom_path)
        error("Waveform ROM file not found: %s", rom_path);
    end
    rom_data{k} = load_signed_hex_rom(rom_path, 16);
end

rom_depth = numel(rom_data{1});
for k = 2:numel(rom_data)
    if numel(rom_data{k}) ~= rom_depth
        error("ROM depth mismatch: %s has %d samples, expected %d", ...
            rom_files(k), numel(rom_data{k}), rom_depth);
    end
end

phase = (0:rom_depth-1).' / rom_depth;
figure("Name", "Floyd waveform ROM time domain");
tiledlayout(numel(rom_data), 1);
for k = 1:numel(rom_data)
    nexttile;
    plot(phase, rom_data{k}, "LineWidth", 1.0);
    grid on;
    xlabel("Phase (cycle)");
    ylabel("Amplitude");
    title(sprintf("%s ROM: %d samples", waveform_names(k), rom_depth));
    xlim([0 1]);
end

figure("Name", "Floyd waveform ROM spectra");
tiledlayout(numel(rom_data), 1);
for k = 1:numel(rom_data)
    nexttile;
    [harmonic, magnitude] = rom_spectrum(rom_data{k});
    plot(harmonic, magnitude, "LineWidth", 1.0);
    grid on;
    xlabel("Harmonic number");
    ylabel("Normalized magnitude");
    title(sprintf("%s ROM harmonic spectrum", waveform_names(k)));
    xlim([0 15]);
end

fprintf("\n=== Waveform ROM checks ===\n");
fprintf("ROM depth               : %d samples\n", rom_depth);
fprintf("ROM format              : signed 16-bit two's complement\n");

check_rom_shape("Sine", rom_data{1}, 0, 32767, 0, -32767);
check_rom_shape("Square", rom_data{2}, 32767, 32767, -32768, -32768);
check_rom_shape("Triangle", rom_data{3}, 0, 32767, 0, -32767);

fprintf("\nHarmonic ratios relative to the fundamental:\n");
fprintf("Waveform   H3       H5       H7       H9       Expected trend\n");
for k = 1:numel(rom_data)
    [~, magnitude] = rom_spectrum(rom_data{k});
    ratios = magnitude([4, 6, 8, 10]) / magnitude(2);
    if k == 1
        trend = "sine: harmonics near zero";
    elseif k == 2
        trend = "square: 1/n for odd n";
    else
        trend = "triangle: 1/n^2 for odd n";
    end
    fprintf("%-9s %.4f   %.4f   %.4f   %.4f   %s\n", ...
        waveform_names(k), ratios(1), ratios(2), ratios(3), ratios(4), trend);
end

fprintf("\nWaveform ROM analysis completed.\n");


function samples = load_signed_hex_rom(path, bits)
    lines = strtrim(readlines(path));
    lines(lines == "") = [];
    raw = hex2dec(char(lines));
    samples = double(raw);
    negative = samples >= 2^(bits - 1);
    samples(negative) = samples(negative) - 2^bits;
    samples = samples(:);
end


function [harmonic, magnitude] = rom_spectrum(samples)
    N = numel(samples);
    spectrum = abs(fft(samples)) / N;
    harmonic = (0:floor(N / 2)).';
    magnitude = spectrum(harmonic + 1);
    magnitude(2:end-1) = 2 * magnitude(2:end-1);
    magnitude = magnitude / max(magnitude(2), eps);
end


function check_rom_shape(name, samples, expected_0, expected_quarter, expected_half, expected_three_quarter)
    N = numel(samples);
    indices = [1, floor(N / 4) + 1, floor(N / 2) + 1, floor(3 * N / 4) + 1];
    expected = double([expected_0, expected_quarter, expected_half, expected_three_quarter]);
    actual = double(samples(indices));
    tolerance = 1;
    passed = all(abs(actual - expected) <= tolerance);

    fprintf("%-9s phase samples: [%d, %d, %d, %d] ", ...
        name, actual(1), actual(2), actual(3), actual(4));
    if passed
        fprintf("PASS\n");
    else
        fprintf("FAIL (expected [%d, %d, %d, %d])\n", ...
            expected(1), expected(2), expected(3), expected(4));
    end
end
