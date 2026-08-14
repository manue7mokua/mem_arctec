module top(
  input clk,
  output [10:0] address,
  output hit_l1,
  output hit_l2,
  output [31:0] performance_counter_l1_hit,
  output [31:0] performance_counter_l1_miss,
  output [31:0] performance_counter_l2_hit,
  output [31:0] performance_counter_l2_miss,
  output [31:0] performance_counter_writeback,
  output [31:0] performance_counter_requests,
  output [31:0] performance_counter_reads,
  output [31:0] performance_counter_writes,
  output [31:0] performance_counter_total_cycles,
  output [31:0] performance_counter_stall_cycles,
  output trace_done
);

  // Use a simpler include path that will work with the -I flag
  `include "src/cache_config.v"

  wire [10:0] cpu_address;
  wire cpu_is_write;
  wire cpu_request_valid;
  wire [31:0] data_l1, data_l2, data_mem;
  wire miss_l1, miss_l2;
  wire dirty_eviction_l1, dirty_eviction_l2;
  
  // Print configuration debug info
  `DEBUG_CONFIG
  
  // Add wires for data promotion
  reg promote_l1_data;
  reg [31:0] promotion_l1_data;
  reg promote_l2_data;
  reg [31:0] promotion_l2_data;
  
  reg [31:0] l1_hit_count = 0;
  reg [31:0] l1_miss_count = 0;
  reg [31:0] l2_hit_count = 0;
  reg [31:0] l2_miss_count = 0;
  reg [31:0] mem_access_count = 0;
  reg [31:0] writeback_count = 0;
  reg [31:0] request_count = 0;
  reg [31:0] read_count = 0;
  reg [31:0] write_count = 0;
  reg [31:0] total_access_cycles = 0;
  reg [31:0] stall_cycle_count = 0;
  reg [31:0] access_cycles = 0;
  
  // Delay registers to maintain correct temporal ordering
  reg [10:0] last_address;
  
  // Instantiate CPU with the trace file
  cpu cpu_inst (
    .clk(clk),
    .request_ready(1'b1),
    .address(cpu_address),
    .is_write(cpu_is_write),
    .request_valid(cpu_request_valid),
    .trace_done(trace_done)
  );
  
  // Instantiate L1 Cache with parameters
  l1_cache #(
    .CACHE_SIZE(`L1_CACHE_SIZE),
    .BLOCK_SIZE(`L1_BLOCK_SIZE),
    .MAPPING_TYPE(`CACHE_MAPPING_L1),
    .REPLACEMENT_POLICY(`REPLACEMENT_POLICY_L1)
  ) l1_cache_inst (
    .clk(clk),
    .address(cpu_address),
    .is_write(cpu_is_write),
    .hit(hit_l1),
    .miss(miss_l1),
    .data_out(data_l1),
    .dirty_eviction(dirty_eviction_l1),
    .promote_data(promote_l1_data),
    .promotion_data(promotion_l1_data)
  );
  
  // Instantiate L2 Cache with parameters
  l2_cache #(
    .CACHE_SIZE(`L2_CACHE_SIZE),
    .BLOCK_SIZE(`L2_BLOCK_SIZE),
    .MAPPING_TYPE(`CACHE_MAPPING_L2),
    .REPLACEMENT_POLICY(`REPLACEMENT_POLICY_L2)
  ) l2_cache_inst (
    .clk(clk),
    .address(cpu_address),
    .l1_miss(miss_l1),
    .is_write(cpu_is_write),
    .hit(hit_l2),
    .miss(miss_l2),
    .data_out(data_l2),
    .dirty_eviction(dirty_eviction_l2),
    .promote_data(promote_l2_data),
    .promotion_data(promotion_l2_data)
  );
  
  // Instantiate Main Memory
  main_memory main_memory_inst (
    .clk(clk),
    .address(cpu_address),
    .l2_miss(miss_l2),
    .data_out(data_mem)
  );
  
  // Connect CPU address to output for display
  assign address = cpu_address;
  
  // Connect performance counters to outputs
  assign performance_counter_l1_hit = l1_hit_count;
  assign performance_counter_l1_miss = l1_miss_count;
  assign performance_counter_l2_hit = l2_hit_count;
  assign performance_counter_l2_miss = l2_miss_count;
  assign performance_counter_writeback = writeback_count;
  assign performance_counter_requests = request_count;
  assign performance_counter_reads = read_count;
  assign performance_counter_writes = write_count;
  assign performance_counter_total_cycles = total_access_cycles;
  assign performance_counter_stall_cycles = stall_cycle_count;
  
  // Handle L1 and L2 cache hits/misses and update performance counters
  always @(posedge clk) begin
    last_address <= cpu_address;
    
    // Reset promotion signals by default
    promote_l1_data <= 0;
    promote_l2_data <= 0;
    if (dirty_eviction_l1 || dirty_eviction_l2) begin
      writeback_count <= writeback_count + dirty_eviction_l1 + dirty_eviction_l2;
    end
    
    if (cpu_request_valid) begin
      request_count <= request_count + 1;
      if (cpu_is_write) begin
        write_count <= write_count + 1;
      end else begin
        read_count <= read_count + 1;
      end

      access_cycles = `L1_LATENCY;

      if (hit_l1) begin
        l1_hit_count <= l1_hit_count + 1;
      end else if (miss_l1) begin
        l1_miss_count <= l1_miss_count + 1;
        access_cycles = access_cycles + `L2_LATENCY;

        if (hit_l2) begin
          l2_hit_count <= l2_hit_count + 1;

          // Promote from L2 to L1
          promote_l1_data <= 1;
          promotion_l1_data <= data_l2;
          $display("Promoting data from L2 to L1: Address=%h, Data=%h", cpu_address, data_l2);
        end else if (miss_l2) begin
          l2_miss_count <= l2_miss_count + 1;
          mem_access_count <= mem_access_count + 1;
          access_cycles = access_cycles + `MEMORY_LATENCY;

          // Promote to L2 first
          promote_l2_data <= 1;
          promotion_l2_data <= data_mem;
          $display("Promoting data from Memory to L2: Address=%h, Data=%h", cpu_address, data_mem);

          // Then promote to L1
          promote_l1_data <= 1;
          promotion_l1_data <= data_mem;
          $display("Promoting data from Memory to L1 & L2: Address=%h, Data=%h", cpu_address, data_mem);
        end
      end

      total_access_cycles <= total_access_cycles + access_cycles;
      if (access_cycles > `L1_LATENCY) begin
        stall_cycle_count <= stall_cycle_count + access_cycles - `L1_LATENCY;
      end

      $display("Access Complete: %s Address=%h, ModeledCycles=%0d", cpu_is_write ? "WRITE" : "READ", cpu_address, access_cycles);
      
      // Calculate and display hit rates and AMAT
      if (l1_hit_count + l1_miss_count > 0) begin
        $display("Performance Metrics:");
        $display("L1 Hits: %d, L1 Misses: %d", l1_hit_count, l1_miss_count);
        $display("L2 Hits: %d, L2 Misses: %d", l2_hit_count, l2_miss_count);
        $display("Requests: %d, Reads: %d, Writes: %d", request_count, read_count, write_count);
        $display("Total Modeled Access Cycles: %d, Stall Cycles: %d", total_access_cycles, stall_cycle_count);
        
        // Calculate and display hit rates
        if (l1_hit_count + l1_miss_count > 0) begin
          $display("L1 Hit Rate: %.2f%%", (l1_hit_count * 100.0) / (l1_hit_count + l1_miss_count));
        end
        
        if (l1_miss_count > 0) begin
          $display("L2 Hit Rate: %.2f%%", (l2_hit_count * 100.0) / l1_miss_count);
        end
        
        // Calculate and display AMAT
        if (l1_miss_count > 0) begin
          $display("AMAT: %.2f cycles", 1.0 + (l1_miss_count * 1.0 / (l1_hit_count + l1_miss_count)) * 
                  (10.0 + (l2_miss_count * 1.0 / l1_miss_count) * 100.0));
        end
      end
    end
  end
endmodule
