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
        default=Path(__file__).resolve().parents[1] / "rom" / "sine.hex",
    )
    args = parser.parse_args()

    if args.depth <= 0 or args.depth & (args.depth - 1):
        raise ValueError("depth must be a positive power of two")
    if args.bits < 2 or args.bits % 4:
        raise ValueError("bits must be a multiple of four and at least two")

    write_hex(args.output, generate_sine(args.depth, args.bits), args.bits)
    print(f"generated {args.output} ({args.depth} samples, {args.bits} bits)")


if __name__ == "__main__":
    main()
