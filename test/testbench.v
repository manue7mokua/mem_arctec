`timescale 1ns / 1ps
`include "src/cache_config.v"

module testbench;
  reg clk = 0;
  wire [10:0] address;
  wire hit_l1, hit_l2;
  wire [31:0] l1_hit_count, l1_miss_count, l2_hit_count, l2_miss_count, writeback_count;
  wire [31:0] request_count, read_count, write_count, total_cycle_count, stall_cycle_count;
  wire trace_done;
  integer hit_rate_l1, hit_rate_l2;
  real hit_rate_l1_real, hit_rate_l2_real, amat;

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
    .trace_done(trace_done)
  );

  always #5 clk = ~clk;

  initial begin
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
    // Let the final accepted request update the counters before reporting.
    #10;
    
    $display("\n*************************************************************");
    $display("* FINAL PERFORMANCE STATISTICS *");
    $display("*************************************************************");
    $display("L1 Hits: %d, L1 Misses: %d", l1_hit_count, l1_miss_count);
    $display("L2 Hits: %d, L2 Misses: %d", l2_hit_count, l2_miss_count);
    $display("Requests: %d, Reads: %d, Writes: %d", request_count, read_count, write_count);
    $display("Dirty Writebacks: %d", writeback_count);
    $display("Actual Transaction Cycles: %d", total_cycle_count);
    $display("Actual Stall Cycles: %d", stall_cycle_count);
    
    if (l1_hit_count + l1_miss_count > 0) begin
      hit_rate_l1 = (l1_hit_count * 100) / (l1_hit_count + l1_miss_count);
      hit_rate_l1_real = hit_rate_l1 / 100.0;
      $display("L1 Hit Rate: %.2f%%", hit_rate_l1_real * 100.0);
    end
    
    if (l1_miss_count > 0) begin
      hit_rate_l2 = (l2_hit_count * 100) / l1_miss_count;
      hit_rate_l2_real = hit_rate_l2 / 100.0;
      $display("L2 Hit Rate: %.2f%%", hit_rate_l2_real * 100.0);
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
    
    $display("*************************************************************");
    $finish;
  end

  initial begin
    #10000000;
    $display("ERROR: Simulation timed out before the trace completed");
    $finish;
  end

endmodule
