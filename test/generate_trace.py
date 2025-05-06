#!/usr/bin/env python3
import random

def generate_trace(num_addresses=10000, output_file="test/large_trace.txt"):
    """Generate a trace file with memory access patterns for cache testing."""
    
    with open(output_file, "w") as f:
        # Sequential access pattern (10%)
        for i in range(int(num_addresses * 0.1)):
            addr = (i * 16) % 2048  # 16-byte stride, wrap around at 2048
            f.write(f"{addr:03X}\n")
        
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
        
        for i in range(int(num_addresses * 0.2)):
            region = random.choice(locality_regions)
            addr = random.randint(region[0], region[1])
            f.write(f"{addr:03X}\n")
        
        # Strided access pattern (15%)
        strides = [16, 32, 64, 128]  # Different stride sizes
        for i in range(int(num_addresses * 0.15)):
            stride = random.choice(strides)
            addr = (i * stride) % 2048
            f.write(f"{addr:03X}\n")
        
        # Loop pattern (25%)
        # Create several small loops that access the same few addresses repeatedly
        num_loops = 10
        addresses_per_loop = int((num_addresses * 0.25) / num_loops)
        
        for loop in range(num_loops):
            # Generate 3-5 random addresses for this loop
            loop_size = random.randint(3, 5)
            loop_addresses = [random.randint(0, 2047) for _ in range(loop_size)]
            
            # Access these addresses repeatedly in the loop
            for i in range(addresses_per_loop):
                addr = loop_addresses[i % loop_size]
                f.write(f"{addr:03X}\n")
        
        # Mixed pattern with cache conflicts (30%)
        # Generate addresses that would map to the same cache sets
        l1_sets = 16  # For direct-mapped L1 cache with 16 sets
        for i in range(int(num_addresses * 0.3)):
            set_index = random.randint(0, l1_sets - 1)
            tag = random.randint(0, 7)  # Random tag
            # Construct address: tag bits + index bits + offset bits (all 0)
            addr = (tag << 8) | (set_index << 4)
            f.write(f"{addr:03X}\n")

if __name__ == "__main__":
    generate_trace(10000, "test/large_trace.txt")
    print("Generated trace file with 10,000 memory addresses") 