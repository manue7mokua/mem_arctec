`timescale 1ns / 1ps

module testbench;
  reg clk = 0;
  wire [10:0] address;
  wire hit_l1, hit_l2;
  wire [31:0] l1_hit_count, l1_miss_count, l2_hit_count, l2_miss_count;
  integer hit_rate_l1, hit_rate_l2;
  real hit_rate_l1_real, hit_rate_l2_real;

  top uut (
    .clk(clk),
    .address(address),
    .hit_l1(hit_l1),
    .hit_l2(hit_l2),
    .performance_counter_l1_hit(l1_hit_count),
    .performance_counter_l1_miss(l1_miss_count),
    .performance_counter_l2_hit(l2_hit_count),
    .performance_counter_l2_miss(l2_miss_count)
  );

  always #5 clk = ~clk;

  initial begin
    $dumpfile("output.vcd");
    $dumpvars(0, testbench);
    $display("Simulation starting...");
    $display("Time | Address | L1 Hit | L2 Hit");
    
    // Run for enough cycles to process more trace entries
    #1000;
    
    // Display final statistics
    $display("\nFinal Performance Statistics:");
    $display("L1 Hits: %d, L1 Misses: %d", l1_hit_count, l1_miss_count);
    $display("L2 Hits: %d, L2 Misses: %d", l2_hit_count, l2_miss_count);
    
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
    
    $finish;
  end

  always @(posedge clk) begin
    $display("%4t | %h |   %b   |   %b", $time, address, hit_l1, hit_l2);
  end

endmodule
