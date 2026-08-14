module main_memory(
  input clk,
  input [10:0] address,
  input write_enable,
  input [31:0] write_data,
  output [31:0] data_out
);
  reg [31:0] memory [0:2047];
  integer i;
  reg verbose;

  initial begin
    verbose = $test$plusargs("VERBOSE");
    for (i = 0; i < 2048; i = i + 1)
      memory[i] = i;
  end

  assign data_out = memory[address];

  always @(posedge clk) begin
    if (write_enable) begin
      memory[address] <= write_data;
      if (verbose)
        $display("MEM_WRITE address=%h data=%h", address, write_data);
    end
  end
endmodule
