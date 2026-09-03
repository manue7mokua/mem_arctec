#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def op_for_index(index: int, write_ratio: float = 0.25) -> str:
    period = max(1, int(1 / write_ratio))
    return "W" if index % period == 0 else "R"


def generate_simple_trace(
    num_addresses: int = 10000,
    output_file: str | Path = "test/simple_trace.txt",
) -> None:
    """Generate a very simple trace file for testing."""
    if num_addresses <= 0:
        raise ValueError("num_addresses must be greater than zero")

    output_path = Path(output_file)
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8") as f:
        # Simple sequential pattern
        for i in range(num_addresses):
            addr = i % 2048  # Wrap around at 2048
            op = op_for_index(i)
            if op == "W":
                data = (0x5A000000 | i) & 0xFFFFFFFF
                f.write(f"W {addr:03X} {data:08X}\n")
            else:
                f.write(f"R {addr:03X}\n")
        
        print(f"Generated simple trace file with {num_addresses} read/write requests")

if __name__ == "__main__":
    generate_simple_trace(10000, "test/simple_trace.txt") 
