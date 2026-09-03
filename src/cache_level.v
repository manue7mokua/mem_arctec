`timescale 1ns / 1ps

module cache_level #(
  parameter CACHE_SIZE = 256,
  parameter BLOCK_SIZE = 16,
  parameter MAPPING_TYPE = 0,
  parameter REPLACEMENT_POLICY = 0,
  parameter ADDRESS_WIDTH = 11,
  parameter DATA_WIDTH = 32,
  parameter RANDOM_SEED = 32'h1,
  parameter LINE_WIDTH = BLOCK_SIZE * 8
)(
  input clk,
  input [ADDRESS_WIDTH-1:0] lookup_address,
  input lookup_is_write,
  input [DATA_WIDTH-1:0] lookup_write_data,
  input lookup_line_write_enable,
  input [LINE_WIDTH-1:0] lookup_line_write_data,
  input access_enable,
  output reg hit,
  output reg miss,
  output reg [DATA_WIDTH-1:0] data_out,
  output reg [LINE_WIDTH-1:0] line_out,
  input fill_enable,
  input [ADDRESS_WIDTH-1:0] fill_address,
  input [LINE_WIDTH-1:0] fill_line,
  input fill_dirty,
  output reg eviction_valid,
  output reg eviction_dirty,
  output reg [ADDRESS_WIDTH-1:0] eviction_address,
  output reg [LINE_WIDTH-1:0] eviction_line
);
  `include "src/cache_config.v"

  localparam WAYS = (MAPPING_TYPE == `DIRECT_MAPPED) ? 1 :
                    (MAPPING_TYPE == `TWO_WAY) ? 2 :
                    (MAPPING_TYPE == `FOUR_WAY) ? 4 : 1;
  localparam NUM_SETS = CACHE_SIZE / BLOCK_SIZE / WAYS;
  localparam OFFSET_BITS = `COMPUTE_OFFSET_BITS(BLOCK_SIZE);
  localparam WORD_OFFSET_BITS = OFFSET_BITS - `COMPUTE_OFFSET_BITS(DATA_WIDTH / 8);
  localparam INDEX_BITS = `COMPUTE_INDEX_BITS(NUM_SETS);
  localparam TAG_BITS = ADDRESS_WIDTH - INDEX_BITS - OFFSET_BITS;

  wire [INDEX_BITS-1:0] lookup_index =
    lookup_address[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
  wire [TAG_BITS-1:0] lookup_tag =
    lookup_address[ADDRESS_WIDTH-1:OFFSET_BITS+INDEX_BITS];
  wire [WORD_OFFSET_BITS-1:0] lookup_word_offset =
    lookup_address[OFFSET_BITS-1:2];
  wire [INDEX_BITS-1:0] fill_index =
    fill_address[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
  wire [TAG_BITS-1:0] fill_tag =
    fill_address[ADDRESS_WIDTH-1:OFFSET_BITS+INDEX_BITS];

  reg valid [0:NUM_SETS-1][0:WAYS-1];
  reg dirty [0:NUM_SETS-1][0:WAYS-1];
  reg [TAG_BITS-1:0] tags [0:NUM_SETS-1][0:WAYS-1];
  reg [LINE_WIDTH-1:0] lines [0:NUM_SETS-1][0:WAYS-1];
  reg [31:0] last_used [0:NUM_SETS-1][0:WAYS-1];
  reg [31:0] use_clock;
  reg [31:0] random_state;

  integer init_set;
  integer init_way;
  integer lookup_iter;
  integer lookup_way;
  integer fill_iter;
  integer fill_way;
  integer lru_way;
  reg invalid_found;

  initial begin
    if (CACHE_SIZE % BLOCK_SIZE != 0)
      $fatal(1, "CACHE_SIZE must be divisible by BLOCK_SIZE");
    if (BLOCK_SIZE % (DATA_WIDTH / 8) != 0)
      $fatal(1, "BLOCK_SIZE must contain complete data words");
    if (LINE_WIDTH != BLOCK_SIZE * 8)
      $fatal(1, "LINE_WIDTH must match BLOCK_SIZE");
    if (MAPPING_TYPE < `DIRECT_MAPPED || MAPPING_TYPE > `FOUR_WAY)
      $fatal(1, "Unsupported cache mapping type: %0d", MAPPING_TYPE);
    if (REPLACEMENT_POLICY < `LRU || REPLACEMENT_POLICY > `RANDOM)
      $fatal(1, "Unsupported replacement policy: %0d", REPLACEMENT_POLICY);
    if (NUM_SETS < 1)
      $fatal(1, "Cache configuration must provide at least one set");

    use_clock = 0;
    random_state = RANDOM_SEED;
    eviction_valid = 0;
    eviction_dirty = 0;
    eviction_address = 0;
    eviction_line = 0;
    for (init_set = 0; init_set < NUM_SETS; init_set = init_set + 1) begin
      for (init_way = 0; init_way < WAYS; init_way = init_way + 1) begin
        valid[init_set][init_way] = 0;
        dirty[init_set][init_way] = 0;
        tags[init_set][init_way] = 0;
        lines[init_set][init_way] = 0;
        last_used[init_set][init_way] = 0;
      end
    end
  end

  always @* begin
    hit = 0;
    miss = 1;
    data_out = 0;
    line_out = 0;
    lookup_way = 0;
    for (lookup_iter = 0; lookup_iter < WAYS; lookup_iter = lookup_iter + 1) begin
      if (valid[lookup_index][lookup_iter] &&
          tags[lookup_index][lookup_iter] == lookup_tag) begin
        hit = 1;
        miss = 0;
        line_out = lines[lookup_index][lookup_iter];
        data_out = lines[lookup_index][lookup_iter]
          [lookup_word_offset * DATA_WIDTH +: DATA_WIDTH];
        lookup_way = lookup_iter;
      end
    end
  end

  always @* begin
    fill_way = 0;
    invalid_found = 0;
    for (fill_iter = 0; fill_iter < WAYS; fill_iter = fill_iter + 1) begin
      if (!invalid_found && !valid[fill_index][fill_iter]) begin
        fill_way = fill_iter;
        invalid_found = 1;
      end
    end

    if (!invalid_found) begin
      if (REPLACEMENT_POLICY == `RANDOM) begin
        fill_way = random_state % WAYS;
      end else begin
        lru_way = 0;
        for (fill_iter = 1; fill_iter < WAYS; fill_iter = fill_iter + 1) begin
          if (last_used[fill_index][fill_iter] < last_used[fill_index][lru_way])
            lru_way = fill_iter;
        end
        fill_way = lru_way;
      end
    end
  end

  always @(posedge clk) begin
    eviction_valid <= 0;
    eviction_dirty <= 0;

    if (fill_enable) begin
      eviction_valid <= valid[fill_index][fill_way];
      eviction_dirty <= valid[fill_index][fill_way] && dirty[fill_index][fill_way];
      eviction_address <= {tags[fill_index][fill_way], fill_index, {OFFSET_BITS{1'b0}}};
      eviction_line <= lines[fill_index][fill_way];

      valid[fill_index][fill_way] <= 1;
      dirty[fill_index][fill_way] <= fill_dirty;
      tags[fill_index][fill_way] <= fill_tag;
      lines[fill_index][fill_way] <= fill_line;
      last_used[fill_index][fill_way] <= use_clock;
      use_clock <= use_clock + 1;
      random_state <= {random_state[30:0],
                       random_state[31] ^ random_state[21] ^
                       random_state[1] ^ random_state[0]};
    end else if (access_enable && hit) begin
      if (lookup_line_write_enable) begin
        lines[lookup_index][lookup_way] <= lookup_line_write_data;
        dirty[lookup_index][lookup_way] <= 1;
      end else if (lookup_is_write) begin
        lines[lookup_index][lookup_way]
          [lookup_word_offset * DATA_WIDTH +: DATA_WIDTH] <= lookup_write_data;
        dirty[lookup_index][lookup_way] <= 1;
      end
      last_used[lookup_index][lookup_way] <= use_clock;
      use_clock <= use_clock + 1;
    end
  end
endmodule
