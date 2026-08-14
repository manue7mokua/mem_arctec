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
  `include "src/cache_config.v"

  localparam ST_IDLE = 0;
  localparam ST_L1_WAIT = 1;
  localparam ST_L2_WAIT = 2;
  localparam ST_MEM_READ_WAIT = 3;
  localparam ST_L2_FILL = 4;
  localparam ST_L2_EVICT_CHECK = 5;
  localparam ST_MEM_WB_WAIT = 6;
  localparam ST_L1_FILL = 7;
  localparam ST_L1_EVICT_CHECK = 8;
  localparam ST_L1_WB_WAIT = 9;

  localparam CONTINUE_L1_FILL = 0;
  localparam CONTINUE_FINISH = 1;

  reg [3:0] state;
  wire [10:0] cpu_address;
  wire cpu_is_write;
  wire [31:0] cpu_write_data;
  wire cpu_request_valid;
  wire cpu_trace_done;
  wire cpu_request_ready = (state == ST_IDLE);

  reg [31:0] delay_count;
  reg [31:0] current_access_cycles;
  reg [10:0] request_address;
  reg request_is_write;
  reg [31:0] request_write_data;

  reg [31:0] pending_l1_fill_data;
  reg [10:0] pending_l2_fill_address;
  reg [31:0] pending_l2_fill_data;
  reg pending_l2_fill_dirty;
  reg l2_fill_continuation;

  reg [10:0] l1_writeback_address;
  reg [31:0] l1_writeback_data;
  reg [10:0] memory_writeback_address;
  reg [31:0] memory_writeback_data;

  reg [31:0] l1_hit_count;
  reg [31:0] l1_miss_count;
  reg [31:0] l2_hit_count;
  reg [31:0] l2_miss_count;
  reg [31:0] writeback_count;
  reg [31:0] request_count;
  reg [31:0] read_count;
  reg [31:0] write_count;
  reg [31:0] total_access_cycles;
  reg [31:0] stall_cycle_count;
  reg verbose;

  wire l1_hit;
  wire l1_miss;
  wire [31:0] l1_data;
  wire l1_eviction_valid;
  wire l1_eviction_dirty;
  wire [10:0] l1_eviction_address;
  wire [31:0] l1_eviction_data;

  wire [10:0] l2_lookup_address =
    (state == ST_L1_WB_WAIT) ? l1_writeback_address : request_address;
  wire l2_lookup_is_write = (state == ST_L1_WB_WAIT);
  wire [31:0] l2_lookup_write_data = l1_writeback_data;
  wire l2_hit;
  wire l2_miss;
  wire [31:0] l2_data;
  wire l2_eviction_valid;
  wire l2_eviction_dirty;
  wire [10:0] l2_eviction_address;
  wire [31:0] l2_eviction_data;

  wire l1_access_enable =
    (state == ST_L1_WAIT && delay_count == 1 && l1_hit);
  wire l2_access_enable =
    (state == ST_L2_WAIT && delay_count == 1 && l2_hit) ||
    (state == ST_L1_WB_WAIT && delay_count == 1 && l2_hit);
  wire l1_fill_enable = (state == ST_L1_FILL);
  wire l2_fill_enable = (state == ST_L2_FILL);

  wire [10:0] memory_address =
    (state == ST_MEM_WB_WAIT) ? memory_writeback_address : request_address;
  wire memory_write_enable =
    (state == ST_MEM_WB_WAIT && delay_count == 1);
  wire [31:0] memory_data;

  assign address = cpu_address;
  assign hit_l1 = l1_hit;
  assign hit_l2 = l2_hit;
  assign trace_done = cpu_trace_done && (state == ST_IDLE);
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

  cpu cpu_inst (
    .clk(clk),
    .request_ready(cpu_request_ready),
    .address(cpu_address),
    .is_write(cpu_is_write),
    .write_data(cpu_write_data),
    .request_valid(cpu_request_valid),
    .trace_done(cpu_trace_done)
  );

  l1_cache #(
    .CACHE_SIZE(`L1_CACHE_SIZE),
    .BLOCK_SIZE(`L1_BLOCK_SIZE),
    .MAPPING_TYPE(`CACHE_MAPPING_L1),
    .REPLACEMENT_POLICY(`REPLACEMENT_POLICY_L1)
  ) l1_cache_inst (
    .clk(clk),
    .lookup_address(request_address),
    .lookup_is_write(request_is_write),
    .lookup_write_data(request_write_data),
    .access_enable(l1_access_enable),
    .hit(l1_hit),
    .miss(l1_miss),
    .data_out(l1_data),
    .fill_enable(l1_fill_enable),
    .fill_address(request_address),
    .fill_data(pending_l1_fill_data),
    .fill_dirty(request_is_write),
    .eviction_valid(l1_eviction_valid),
    .eviction_dirty(l1_eviction_dirty),
    .eviction_address(l1_eviction_address),
    .eviction_data(l1_eviction_data)
  );

  l2_cache #(
    .CACHE_SIZE(`L2_CACHE_SIZE),
    .BLOCK_SIZE(`L2_BLOCK_SIZE),
    .MAPPING_TYPE(`CACHE_MAPPING_L2),
    .REPLACEMENT_POLICY(`REPLACEMENT_POLICY_L2)
  ) l2_cache_inst (
    .clk(clk),
    .lookup_address(l2_lookup_address),
    .lookup_is_write(l2_lookup_is_write),
    .lookup_write_data(l2_lookup_write_data),
    .access_enable(l2_access_enable),
    .hit(l2_hit),
    .miss(l2_miss),
    .data_out(l2_data),
    .fill_enable(l2_fill_enable),
    .fill_address(pending_l2_fill_address),
    .fill_data(pending_l2_fill_data),
    .fill_dirty(pending_l2_fill_dirty),
    .eviction_valid(l2_eviction_valid),
    .eviction_dirty(l2_eviction_dirty),
    .eviction_address(l2_eviction_address),
    .eviction_data(l2_eviction_data)
  );

  main_memory main_memory_inst (
    .clk(clk),
    .address(memory_address),
    .write_enable(memory_write_enable),
    .write_data(memory_writeback_data),
    .data_out(memory_data)
  );

  task complete_request;
    input [31:0] elapsed_cycles;
    begin
      total_access_cycles <= total_access_cycles + elapsed_cycles;
      if (elapsed_cycles > 1)
        stall_cycle_count <= stall_cycle_count + elapsed_cycles - 1;
      if (verbose)
        $display("REQUEST_COMPLETE op=%s address=%h data=%h cycles=%0d",
                 request_is_write ? "W" : "R", request_address,
                 request_is_write ? request_write_data : l1_data,
                 elapsed_cycles);
      state <= ST_IDLE;
    end
  endtask

  initial begin
    verbose = $test$plusargs("VERBOSE");
    state = ST_IDLE;
    delay_count = 0;
    current_access_cycles = 0;
    request_address = 0;
    request_is_write = 0;
    request_write_data = 0;
    pending_l1_fill_data = 0;
    pending_l2_fill_address = 0;
    pending_l2_fill_data = 0;
    pending_l2_fill_dirty = 0;
    l2_fill_continuation = CONTINUE_L1_FILL;
    l1_writeback_address = 0;
    l1_writeback_data = 0;
    memory_writeback_address = 0;
    memory_writeback_data = 0;
    l1_hit_count = 0;
    l1_miss_count = 0;
    l2_hit_count = 0;
    l2_miss_count = 0;
    writeback_count = 0;
    request_count = 0;
    read_count = 0;
    write_count = 0;
    total_access_cycles = 0;
    stall_cycle_count = 0;
  end

  always @(posedge clk) begin
    if (state != ST_IDLE)
      current_access_cycles <= current_access_cycles + 1;

    case (state)
      ST_IDLE: begin
        if (cpu_request_valid) begin
          request_address <= cpu_address;
          request_is_write <= cpu_is_write;
          request_write_data <= cpu_write_data;
          request_count <= request_count + 1;
          if (cpu_is_write)
            write_count <= write_count + 1;
          else
            read_count <= read_count + 1;
          current_access_cycles <= 0;
          delay_count <= `L1_LATENCY;
          state <= ST_L1_WAIT;
        end
      end

      ST_L1_WAIT: begin
        if (delay_count > 1) begin
          delay_count <= delay_count - 1;
        end else if (l1_hit) begin
          l1_hit_count <= l1_hit_count + 1;
          complete_request(current_access_cycles + 1);
        end else begin
          l1_miss_count <= l1_miss_count + 1;
          delay_count <= `L2_LATENCY;
          state <= ST_L2_WAIT;
        end
      end

      ST_L2_WAIT: begin
        if (delay_count > 1) begin
          delay_count <= delay_count - 1;
        end else if (l2_hit) begin
          l2_hit_count <= l2_hit_count + 1;
          pending_l1_fill_data <= request_is_write ? request_write_data : l2_data;
          state <= ST_L1_FILL;
        end else begin
          l2_miss_count <= l2_miss_count + 1;
          delay_count <= `MEMORY_LATENCY;
          state <= ST_MEM_READ_WAIT;
        end
      end

      ST_MEM_READ_WAIT: begin
        if (delay_count > 1) begin
          delay_count <= delay_count - 1;
        end else begin
          pending_l2_fill_address <= request_address;
          pending_l2_fill_data <= memory_data;
          pending_l2_fill_dirty <= 0;
          pending_l1_fill_data <= request_is_write ? request_write_data : memory_data;
          l2_fill_continuation <= CONTINUE_L1_FILL;
          state <= ST_L2_FILL;
        end
      end

      ST_L2_FILL: begin
        state <= ST_L2_EVICT_CHECK;
      end

      ST_L2_EVICT_CHECK: begin
        if (l2_eviction_valid && l2_eviction_dirty) begin
          writeback_count <= writeback_count + 1;
          memory_writeback_address <= l2_eviction_address;
          memory_writeback_data <= l2_eviction_data;
          delay_count <= `MEMORY_LATENCY;
          state <= ST_MEM_WB_WAIT;
        end else if (l2_fill_continuation == CONTINUE_L1_FILL) begin
          state <= ST_L1_FILL;
        end else begin
          complete_request(current_access_cycles + 1);
        end
      end

      ST_MEM_WB_WAIT: begin
        if (delay_count > 1) begin
          delay_count <= delay_count - 1;
        end else if (l2_fill_continuation == CONTINUE_L1_FILL) begin
          state <= ST_L1_FILL;
        end else begin
          complete_request(current_access_cycles + 1);
        end
      end

      ST_L1_FILL: begin
        state <= ST_L1_EVICT_CHECK;
      end

      ST_L1_EVICT_CHECK: begin
        if (l1_eviction_valid && l1_eviction_dirty) begin
          writeback_count <= writeback_count + 1;
          l1_writeback_address <= l1_eviction_address;
          l1_writeback_data <= l1_eviction_data;
          delay_count <= `L2_LATENCY;
          state <= ST_L1_WB_WAIT;
        end else begin
          complete_request(current_access_cycles + 1);
        end
      end

      ST_L1_WB_WAIT: begin
        if (delay_count > 1) begin
          delay_count <= delay_count - 1;
        end else if (l2_hit) begin
          complete_request(current_access_cycles + 1);
        end else begin
          pending_l2_fill_address <= l1_writeback_address;
          pending_l2_fill_data <= l1_writeback_data;
          pending_l2_fill_dirty <= 1;
          l2_fill_continuation <= CONTINUE_FINISH;
          state <= ST_L2_FILL;
        end
      end

      default: state <= ST_IDLE;
    endcase
  end
endmodule
