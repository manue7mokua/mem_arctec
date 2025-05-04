all: compile run

compile:
	iverilog -o cache_sim src/*.v test/testbench.v

run:
	vvp cache_sim

clean:
	rm -f cache_sim output.vcd 