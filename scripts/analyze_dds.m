% Floyd DDS output analysis.
% Run this script from the Floyd project root after HDL simulation.

clear;
close all;
clc;

sample_file = "../simulation_outputs/dds_samples.txt";
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