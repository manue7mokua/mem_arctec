#!/usr/bin/env python3

def generate_simple_trace(num_addresses=10000, output_file="test/simple_trace.txt"):
    """Generate a very simple trace file for testing."""
    
    with open(output_file, "w") as f:
        # Simple sequential pattern
        for i in range(num_addresses):
            addr = i % 2048  # Wrap around at 2048
            f.write(f"{addr:03X}\n")
        
        print(f"Generated simple trace file with {num_addresses} addresses")

if __name__ == "__main__":
    generate_simple_trace(10000, "test/simple_trace.txt") 