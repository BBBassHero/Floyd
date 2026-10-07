#!/usr/bin/env python3
"""Generate fixed-point waveform ROM files for the Floyd synth engine."""

from __future__ import annotations

import argparse
import math
from pathlib import Path


def to_signed_hex(value: int, bits: int = 16) -> str:
    mask = (1 << bits) - 1
    return f"{value & mask:0{bits // 4}X}"


def generate_sine(depth: int, bits: int) -> list[int]:
    peak = (1 << (bits - 1)) - 1
    return [round(math.sin(2.0 * math.pi * i / depth) * peak) for i in range(depth)]


def generate_square(depth: int, bits: int) -> list[int]:
    positive_peak = (1 << (bits - 1)) - 1
    negative_peak = -(1 << (bits - 1))
    return [positive_peak if i < depth // 2 else negative_peak for i in range(depth)]


def generate_triangle(depth: int, bits: int) -> list[int]:
    peak = (1 << (bits - 1)) - 1
    values = []
    for i in range(depth):
        phase = i / depth
        if phase < 0.25:
            normalized = 4.0 * phase
        elif phase < 0.75:
            normalized = 2.0 - 4.0 * phase
        else:
            normalized = -4.0 + 4.0 * phase
        values.append(round(normalized * peak))
    return values


def write_hex(path: Path, values: list[int], bits: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "\n".join(to_signed_hex(value, bits) for value in values) + "\n",
        encoding="ascii",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--depth", type=int, default=1024)
    parser.add_argument("--bits", type=int, default=16)
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
    )
    args = parser.parse_args()

    if args.depth <= 0 or args.depth & (args.depth - 1):
        raise ValueError("depth must be a positive power of two")
    if args.bits < 2 or args.bits % 4:
        raise ValueError("bits must be a multiple of four and at least two")

    rom_dir = Path(__file__).resolve().parents[1] / "rom"
    if args.output is not None:
        write_hex(args.output, generate_sine(args.depth, args.bits), args.bits)
        print(f"generated {args.output} ({args.depth} samples, {args.bits} bits)")
    else:
        outputs = {
            "sine.hex": generate_sine(args.depth, args.bits),
            "square.hex": generate_square(args.depth, args.bits),
            "triangle.hex": generate_triangle(args.depth, args.bits),
        }
        for filename, values in outputs.items():
            output = rom_dir / filename
            write_hex(output, values, args.bits)
            print(f"generated {output} ({args.depth} samples, {args.bits} bits)")


if __name__ == "__main__":
    main()
