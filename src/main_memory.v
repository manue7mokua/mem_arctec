module main_memory(input clk, input [10:0] address, input l2_miss, output reg [31:0] data_out);
  reg [31:0] memory[0:2047];
  integer i;

  initial begin
    for (i = 0; i < 2048; i = i + 1) begin
      memory[i] = i;  // Simple data pattern where each memory location contains its own address
    end
  end

  always @(posedge clk) begin
    if (l2_miss) begin
      data_out <= memory[address];
      $display("Main Memory Access: Address=%h, Data=%h", address, memory[address]);
    end
  end
endmodule
