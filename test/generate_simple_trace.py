#!/usr/bin/env python3

def op_for_index(index, write_ratio=0.25):
    period = max(1, int(1 / write_ratio))
    return "W" if index % period == 0 else "R"


def generate_simple_trace(num_addresses=10000, output_file="test/simple_trace.txt"):
    """Generate a very simple trace file for testing."""
    
    with open(output_file, "w") as f:
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
