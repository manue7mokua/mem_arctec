# Makefile for the two-level cache hierarchy simulation

# Default target
all: direct_mapped

# Compiler and flags
IVERILOG = iverilog
IVERILOG_FLAGS = -o
VVP = vvp

# Simulation output
SIM_OUT = cache_sim

# Source files - specify with full paths
SRC_FILES = src/cpu.v src/l1_cache.v src/l2_cache.v src/main_memory.v src/top.v test/testbench.v
INC_PATH = -I.

# Different cache configurations
direct_mapped: $(SRC_FILES)
	@echo "Compiling Direct-Mapped configuration..."
	$(IVERILOG) $(IVERILOG_FLAGS) $(SIM_OUT) $(INC_PATH) -DCACHE_MAPPING_L1=0 -DCACHE_MAPPING_L2=0 $(SRC_FILES)
	@echo "Running simulation..."
	$(VVP) $(SIM_OUT)
	@cp output.vcd waveform_direct_mapped.vcd
	@echo "Waveform saved to waveform_direct_mapped.vcd"

two_way_lru: $(SRC_FILES)
	@echo "Compiling 2-Way Set Associative with LRU configuration..."
	$(IVERILOG) $(IVERILOG_FLAGS) $(SIM_OUT) $(INC_PATH) -DCACHE_MAPPING_L1=1 -DCACHE_MAPPING_L2=1 -DREPLACEMENT_POLICY_L1=0 -DREPLACEMENT_POLICY_L2=0 $(SRC_FILES)
	@echo "Running simulation..."
	$(VVP) $(SIM_OUT)
	@cp output.vcd waveform_two_way_lru.vcd
	@echo "Waveform saved to waveform_two_way_lru.vcd"

two_way_random: $(SRC_FILES)
	@echo "Compiling 2-Way Set Associative with Random replacement configuration..."
	$(IVERILOG) $(IVERILOG_FLAGS) $(SIM_OUT) $(INC_PATH) -DCACHE_MAPPING_L1=1 -DCACHE_MAPPING_L2=1 -DREPLACEMENT_POLICY_L1=1 -DREPLACEMENT_POLICY_L2=1 $(SRC_FILES)
	@echo "Running simulation..."
	$(VVP) $(SIM_OUT)
	@cp output.vcd waveform_two_way_random.vcd
	@echo "Waveform saved to waveform_two_way_random.vcd"

four_way_lru: $(SRC_FILES)
	@echo "Compiling 4-Way Set Associative with LRU configuration..."
	$(IVERILOG) $(IVERILOG_FLAGS) $(SIM_OUT) $(INC_PATH) -DCACHE_MAPPING_L1=2 -DCACHE_MAPPING_L2=2 -DREPLACEMENT_POLICY_L1=0 -DREPLACEMENT_POLICY_L2=0 $(SRC_FILES)
	@echo "Running simulation..."
	$(VVP) $(SIM_OUT)
	@cp output.vcd waveform_four_way_lru.vcd
	@echo "Waveform saved to waveform_four_way_lru.vcd"

four_way_random: $(SRC_FILES)
	@echo "Compiling 4-Way Set Associative with Random replacement configuration..."
	$(IVERILOG) $(IVERILOG_FLAGS) $(SIM_OUT) $(INC_PATH) -DCACHE_MAPPING_L1=2 -DCACHE_MAPPING_L2=2 -DREPLACEMENT_POLICY_L1=1 -DREPLACEMENT_POLICY_L2=1 $(SRC_FILES)
	@echo "Running simulation..."
	$(VVP) $(SIM_OUT)
	@cp output.vcd waveform_four_way_random.vcd
	@echo "Waveform saved to waveform_four_way_random.vcd"

mixed: $(SRC_FILES)
	@echo "Compiling mixed configuration (L1: 2-Way LRU, L2: 4-Way Random)..."
	$(IVERILOG) $(IVERILOG_FLAGS) $(SIM_OUT) $(INC_PATH) -DCACHE_MAPPING_L1=1 -DCACHE_MAPPING_L2=2 -DREPLACEMENT_POLICY_L1=0 -DREPLACEMENT_POLICY_L2=1 $(SRC_FILES)
	@echo "Running simulation..."
	$(VVP) $(SIM_OUT)
	@cp output.vcd waveform_mixed.vcd
	@echo "Waveform saved to waveform_mixed.vcd"

# Run all configurations and compare results
compare: $(SRC_FILES)
	@echo "Running all cache configurations for comparison..."
	@make direct_mapped > results_direct_mapped.txt
	@make two_way_lru > results_two_way_lru.txt
	@make two_way_random > results_two_way_random.txt
	@make four_way_lru > results_four_way_lru.txt
	@make four_way_random > results_four_way_random.txt
	@make mixed > results_mixed.txt
	@echo "All configurations have been tested."
	@echo "Results saved to results_*.txt files."
	@echo "Waveforms saved to waveform_*.vcd files."
	@echo "------------------------------------------------------------"
	@echo "SUMMARY OF FINAL RESULTS:"
	@echo "------------------------------------------------------------"
	@echo "DIRECT MAPPED:"
	@grep "L1 Hit Rate" results_direct_mapped.txt
	@grep "L2 Hit Rate" results_direct_mapped.txt
	@grep "AMAT" results_direct_mapped.txt
	@echo "------------------------------------------------------------"
	@echo "2-WAY SET ASSOCIATIVE WITH LRU:"
	@grep "L1 Hit Rate" results_two_way_lru.txt
	@grep "L2 Hit Rate" results_two_way_lru.txt
	@grep "AMAT" results_two_way_lru.txt
	@echo "------------------------------------------------------------"
	@echo "2-WAY SET ASSOCIATIVE WITH RANDOM:"
	@grep "L1 Hit Rate" results_two_way_random.txt
	@grep "L2 Hit Rate" results_two_way_random.txt
	@grep "AMAT" results_two_way_random.txt
	@echo "------------------------------------------------------------"
	@echo "4-WAY SET ASSOCIATIVE WITH LRU:"
	@grep "L1 Hit Rate" results_four_way_lru.txt
	@grep "L2 Hit Rate" results_four_way_lru.txt
	@grep "AMAT" results_four_way_lru.txt
	@echo "------------------------------------------------------------"
	@echo "4-WAY SET ASSOCIATIVE WITH RANDOM:"
	@grep "L1 Hit Rate" results_four_way_random.txt
	@grep "L2 Hit Rate" results_four_way_random.txt
	@grep "AMAT" results_four_way_random.txt
	@echo "------------------------------------------------------------"
	@echo "MIXED CONFIGURATION (L1: 2-WAY LRU, L2: 4-WAY RANDOM):"
	@grep "L1 Hit Rate" results_mixed.txt
	@grep "L2 Hit Rate" results_mixed.txt
	@grep "AMAT" results_mixed.txt
	@echo "------------------------------------------------------------"

# View waveform 
view_waveform:
	@echo "Available waveform files:"
	@ls -l waveform_*.vcd 2>/dev/null || echo "No waveform files found"
	@echo "To view a waveform, use: gtkwave <waveform_file.vcd>"
	@echo "Or upload to https://vc.drom.io/"

# Clean up
clean:
	rm -f $(SIM_OUT) output.vcd results_*.txt waveform_*.vcd

.PHONY: all direct_mapped two_way_lru two_way_random four_way_lru four_way_random mixed compare view_waveform clean 