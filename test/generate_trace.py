#!/usr/bin/env python3
import random
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

def random_op(rng, write_ratio=0.30):
    return "W" if rng.random() < write_ratio else "R"


def generate_trace(num_addresses=10000, output_file="test/large_trace.txt", seed=20260823):
    """Generate a trace file with memory access patterns for cache testing."""
    rng = random.Random(seed)
    output_path = Path(output_file)
    if not output_path.is_absolute():
        output_path = ROOT / output_path

    sequential_count = num_addresses * 10 // 100
    locality_count = num_addresses * 20 // 100
    stride_count = num_addresses * 15 // 100
    loop_count = num_addresses * 25 // 100
    mixed_count = num_addresses - (
        sequential_count + locality_count + stride_count + loop_count
    )

    with output_path.open("w", encoding="utf-8") as f:
        request_index = 0

        def emit(addr, write_ratio):
            nonlocal request_index
            op = random_op(rng, write_ratio)
            if op == "W":
                data = (0xA5000000 ^ (request_index << 11) ^ addr) & 0xFFFFFFFF
                f.write(f"W {addr:03X} {data:08X}\n")
            else:
                f.write(f"R {addr:03X}\n")
            request_index += 1

        # Sequential access pattern (10%)
        for i in range(sequential_count):
            addr = (i * 16) % 2048  # 16-byte stride, wrap around at 2048
            emit(addr, 0.10)
        
        # Random access pattern with locality (20%)
        locality_regions = [
            (0x000, 0x0FF),    # Region 1: 0-255
            (0x100, 0x1FF),    # Region 2: 256-511
            (0x200, 0x2FF),    # Region 3: 512-767
            (0x300, 0x3FF),    # Region 4: 768-1023
            (0x400, 0x4FF),    # Region 5: 1024-1279
            (0x500, 0x5FF),    # Region 6: 1280-1535
            (0x600, 0x6FF),    # Region 7: 1536-1791
            (0x700, 0x7FF),    # Region 8: 1792-2047
        ]
        
        for i in range(locality_count):
            region = rng.choice(locality_regions)
            addr = rng.randint(region[0], region[1])
            emit(addr, 0.25)
        
        # Strided access pattern (15%)
        strides = [16, 32, 64, 128]  # Different stride sizes
        for i in range(stride_count):
            stride = rng.choice(strides)
            addr = (i * stride) % 2048
            emit(addr, 0.20)
        
        # Loop pattern (25%)
        # Create several small loops that access the same few addresses repeatedly
        num_loops = 10

        for loop in range(num_loops):
            # Generate 3-5 random addresses for this loop
            loop_size = rng.randint(3, 5)
            loop_addresses = [rng.randint(0, 2047) for _ in range(loop_size)]

            # Access these addresses repeatedly in the loop
            addresses_per_loop = loop_count // num_loops
            if loop < loop_count % num_loops:
                addresses_per_loop += 1
            for i in range(addresses_per_loop):
                addr = loop_addresses[i % loop_size]
                emit(addr, 0.35)
        
        # Mixed pattern with cache conflicts (30%)
        # Generate addresses that would map to the same cache sets
        l1_sets = 16  # For direct-mapped L1 cache with 16 sets
        for i in range(mixed_count):
            set_index = rng.randint(0, l1_sets - 1)
            tag = rng.randint(0, 7)  # Random tag
            # Construct address: tag bits + index bits + offset bits (all 0)
            addr = (tag << 8) | (set_index << 4)
            emit(addr, 0.45)

if __name__ == "__main__":
    generate_trace(10000, "test/large_trace.txt")
    print("Generated trace file with 10,000 read/write requests") 
