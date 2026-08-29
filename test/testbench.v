`timescale 1ns / 1ps
`include "src/cache_config.v"

module testbench;
  reg clk = 0;
  wire [10:0] address;
  wire hit_l1, hit_l2;
  wire [31:0] l1_hit_count, l1_miss_count, l2_hit_count, l2_miss_count, writeback_count;
  wire [31:0] request_count, read_count, write_count, total_cycle_count, stall_cycle_count;
  wire [31:0] l1_line_fill_count, l2_line_fill_count;
  wire [31:0] memory_line_read_count, memory_line_write_count;
  wire trace_done;
  wire response_valid, response_is_write;
  wire [10:0] response_address;
  wire [31:0] response_data;
  real hit_rate_l1_real, hit_rate_l2_real, amat;
  integer response_count = 0;
  integer data_error_count = 0;
  integer expected_init;
  reg [31:0] expected_words [0:511];
  reg check_data;

  // Define which cache configuration we're testing
  // By default, use the configuration from cache_config.v
  // Can override with command-line parameters during compilation:
  // For example: iverilog -DCACHE_MAPPING_L1=0 -DCACHE_MAPPING_L2=0 ...
  
  localparam CACHE_CONFIG_NAMES = 3;
  reg [63:0] config_names [0:2];
  initial begin
    config_names[`DIRECT_MAPPED] = "DIRECT MAPPED";
    config_names[`TWO_WAY] = "2-WAY SET ASSOCIATIVE";
    config_names[`FOUR_WAY] = "4-WAY SET ASSOCIATIVE";
  end
  
  localparam REPLACEMENT_NAMES = 2;
  reg [63:0] replacement_names [0:1];
  initial begin
    replacement_names[`LRU] = "LRU";
    replacement_names[`RANDOM] = "RANDOM";
  end

  top uut (
    .clk(clk),
    .address(address),
    .hit_l1(hit_l1),
    .hit_l2(hit_l2),
    .performance_counter_l1_hit(l1_hit_count),
    .performance_counter_l1_miss(l1_miss_count),
    .performance_counter_l2_hit(l2_hit_count),
    .performance_counter_l2_miss(l2_miss_count),
    .performance_counter_writeback(writeback_count),
    .performance_counter_requests(request_count),
    .performance_counter_reads(read_count),
    .performance_counter_writes(write_count),
    .performance_counter_total_cycles(total_cycle_count),
    .performance_counter_stall_cycles(stall_cycle_count),
    .performance_counter_l1_line_fills(l1_line_fill_count),
    .performance_counter_l2_line_fills(l2_line_fill_count),
    .performance_counter_memory_line_reads(memory_line_read_count),
    .performance_counter_memory_line_writes(memory_line_write_count),
    .trace_done(trace_done),
    .response_valid(response_valid),
    .response_is_write(response_is_write),
    .response_address(response_address),
    .response_data(response_data)
  );

  always #5 clk = ~clk;

  initial begin
    check_data = $test$plusargs("CHECK_DATA");
    for (expected_init = 0; expected_init < 512; expected_init = expected_init + 1)
      expected_words[expected_init] = expected_init * 4;

    if ($test$plusargs("VCD")) begin
      $dumpfile("output.vcd");
      $dumpvars(0, testbench);
    end
    
    $display("\n*************************************************************");
    $display("* CACHE HIERARCHY SIMULATION - CONFIGURATION *");
    $display("*************************************************************");
    
    if (`CACHE_MAPPING_L1 == `DIRECT_MAPPED) begin
      $display("L1 Cache: DIRECT MAPPED");
    end else if (`CACHE_MAPPING_L1 == `TWO_WAY) begin
      if (`REPLACEMENT_POLICY_L1 == `LRU) begin
        $display("L1 Cache: 2-WAY SET ASSOCIATIVE with LRU replacement");
      end else begin
        $display("L1 Cache: 2-WAY SET ASSOCIATIVE with RANDOM replacement");
      end
    end else if (`CACHE_MAPPING_L1 == `FOUR_WAY) begin
      if (`REPLACEMENT_POLICY_L1 == `LRU) begin
        $display("L1 Cache: 4-WAY SET ASSOCIATIVE with LRU replacement");
      end else begin
        $display("L1 Cache: 4-WAY SET ASSOCIATIVE with RANDOM replacement");
      end
    end else begin
      $display("L1 Cache: UNKNOWN CONFIGURATION");
    end
    
    if (`CACHE_MAPPING_L2 == `DIRECT_MAPPED) begin
      $display("L2 Cache: DIRECT MAPPED");
    end else if (`CACHE_MAPPING_L2 == `TWO_WAY) begin
      if (`REPLACEMENT_POLICY_L2 == `LRU) begin
        $display("L2 Cache: 2-WAY SET ASSOCIATIVE with LRU replacement");
      end else begin
        $display("L2 Cache: 2-WAY SET ASSOCIATIVE with RANDOM replacement");
      end
    end else if (`CACHE_MAPPING_L2 == `FOUR_WAY) begin
      if (`REPLACEMENT_POLICY_L2 == `LRU) begin
        $display("L2 Cache: 4-WAY SET ASSOCIATIVE with LRU replacement");
      end else begin
        $display("L2 Cache: 4-WAY SET ASSOCIATIVE with RANDOM replacement");
      end
    end else begin
      $display("L2 Cache: UNKNOWN CONFIGURATION");
    end
    
    $display("L1 Size: %d bytes, Block size: %d bytes", `L1_CACHE_SIZE, `L1_BLOCK_SIZE);
    $display("L2 Size: %d bytes, Block size: %d bytes", `L2_CACHE_SIZE, `L2_BLOCK_SIZE);
    $display("*************************************************************\n");
    
    $display("Simulation starting; it will stop after the trace completes...");

    wait (trace_done);
    // Let the final response pulse reach the scoreboard before reporting.
    @(posedge clk);
    #1;
    
    $display("\n*************************************************************");
    $display("* FINAL PERFORMANCE STATISTICS *");
    $display("*************************************************************");
    $display("L1 Hits: %d, L1 Misses: %d", l1_hit_count, l1_miss_count);
    $display("L2 Hits: %d, L2 Misses: %d", l2_hit_count, l2_miss_count);
    $display("Requests: %d, Reads: %d, Writes: %d", request_count, read_count, write_count);
    $display("Dirty Writebacks: %d", writeback_count);
    $display("Actual Transaction Cycles: %d", total_cycle_count);
    $display("Actual Stall Cycles: %d", stall_cycle_count);
    $display("Line Fills: L1=%0d, L2=%0d", l1_line_fill_count, l2_line_fill_count);
    $display("Memory Line Traffic: Reads=%0d, Writes=%0d",
             memory_line_read_count, memory_line_write_count);
    
    if (l1_hit_count + l1_miss_count > 0) begin
      hit_rate_l1_real = (l1_hit_count * 100.0) / (l1_hit_count + l1_miss_count);
      $display("L1 Hit Rate: %.2f%%", hit_rate_l1_real);
    end
    
    if (l1_miss_count > 0) begin
      hit_rate_l2_real = (l2_hit_count * 100.0) / l1_miss_count;
      $display("L2 Hit Rate: %.2f%%", hit_rate_l2_real);
    end
    
    amat = 1.0;
    if (l1_hit_count + l1_miss_count > 0) begin
      amat = amat + (l1_miss_count * 1.0 / (l1_hit_count + l1_miss_count)) * 
             (10.0 + (l2_miss_count * 1.0 / l1_miss_count) * 100.0);
      $display("Analytical Demand AMAT: %.2f cycles", amat);
    end

    if (request_count > 0) begin
      $display("Measured Average Transaction Cost: %.2f cycles", (total_cycle_count * 1.0) / request_count);
    end

    $display("RESULT requests=%0d reads=%0d writes=%0d l1_hits=%0d l1_misses=%0d l2_hits=%0d l2_misses=%0d writebacks=%0d cycles=%0d stalls=%0d responses=%0d data_errors=%0d l1_fills=%0d l2_fills=%0d memory_reads=%0d memory_writes=%0d",
             request_count, read_count, write_count, l1_hit_count, l1_miss_count,
             l2_hit_count, l2_miss_count, writeback_count, total_cycle_count,
             stall_cycle_count, response_count, data_error_count,
             l1_line_fill_count, l2_line_fill_count,
             memory_line_read_count, memory_line_write_count);

    if (response_count != request_count) begin
      $display("ERROR: response count %0d does not match request count %0d",
               response_count, request_count);
      $fatal(1);
    end
    if (check_data && data_error_count != 0)
      $fatal(1);
    
    $display("*************************************************************");
    $finish;
  end

  initial begin
    #10000000;
    $display("ERROR: Simulation timed out before the trace completed");
    $finish;
  end

  always @(posedge clk) begin
    if (response_valid) begin
      response_count = response_count + 1;
      if (response_is_write) begin
        expected_words[response_address[10:2]] = response_data;
      end else if (check_data &&
                   response_data !== expected_words[response_address[10:2]]) begin
        data_error_count = data_error_count + 1;
        $display("DATA_MISMATCH address=%h expected=%h actual=%h",
                 response_address, expected_words[response_address[10:2]], response_data);
      end
    end
  end

endmodule
