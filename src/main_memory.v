`include "src/cache_config.v"

module main_memory(
  input clk,
  input [10:0] address,
  input write_enable,
  input [`L2_LINE_WIDTH-1:0] write_line,
  output reg [`L2_LINE_WIDTH-1:0] line_out
);
  localparam WORDS_PER_LINE = `L2_BLOCK_SIZE / `BYTES_PER_WORD;
  localparam L2_OFFSET_BITS = `COMPUTE_OFFSET_BITS(`L2_BLOCK_SIZE);
  reg [`DATA_WIDTH-1:0] memory [0:`MEMORY_WORDS-1];
  wire [10:0] line_base_address =
    {address[10:L2_OFFSET_BITS], {L2_OFFSET_BITS{1'b0}}};
  wire [8:0] line_base_word = line_base_address[10:2];
  integer i;
  integer read_word;
  integer write_word;
  reg verbose;

  initial begin
    verbose = $test$plusargs("VERBOSE");
    for (i = 0; i < `MEMORY_WORDS; i = i + 1)
      memory[i] = i * `BYTES_PER_WORD;
  end

  always @* begin
    line_out = 0;
    for (read_word = 0; read_word < WORDS_PER_LINE; read_word = read_word + 1)
      line_out[read_word * `DATA_WIDTH +: `DATA_WIDTH] =
        memory[line_base_word + read_word];
  end

  always @(posedge clk) begin
    if (write_enable) begin
      for (write_word = 0; write_word < WORDS_PER_LINE; write_word = write_word + 1)
        memory[line_base_word + write_word] <=
          write_line[write_word * `DATA_WIDTH +: `DATA_WIDTH];
      if (verbose)
        $display("MEM_LINE_WRITE address=%h line=%h", line_base_address, write_line);
    end
  end
endmodule
