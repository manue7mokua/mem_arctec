module cpu(input clk, output reg [10:0] address);
  // We have a maximum of 200 addresses in our trace file to handle the extended trace
  parameter MAX_TRACE_SIZE = 200;
  reg [10:0] trace_mem[0:MAX_TRACE_SIZE-1];
  integer i = 0;
  integer trace_size = 0;
  integer file, status, char, line_count;
  reg [10:0] addr_val;
  reg [8*80-1:0] line; // 80-character buffer for reading each line

  initial begin
    // Initialize memory array to avoid X values
    for (i = 0; i < MAX_TRACE_SIZE; i = i + 1) begin
      trace_mem[i] = 11'h0;
    end
    
    // Read the trace file manually line by line
    file = $fopen("test/test_trace.txt", "r");
    if (file == 0) begin
      $display("Error: Could not open trace file");
      $finish;
    end
    
    line_count = 0;
    
    while (!$feof(file) && line_count < MAX_TRACE_SIZE) begin
      status = $fgets(line, file);
      
      // Check if it's not a comment or blank line (must start with a hex digit)
      if (line[79:72] == "0" || 
          line[79:72] == "1" || 
          line[79:72] == "2" || 
          line[79:72] == "3" || 
          line[79:72] == "4" || 
          line[79:72] == "5" || 
          line[79:72] == "6" || 
          line[79:72] == "7" || 
          line[79:72] == "8" || 
          line[79:72] == "9" || 
          line[79:72] == "a" || line[79:72] == "A" || 
          line[79:72] == "b" || line[79:72] == "B" || 
          line[79:72] == "c" || line[79:72] == "C" || 
          line[79:72] == "d" || line[79:72] == "D" || 
          line[79:72] == "e" || line[79:72] == "E" || 
          line[79:72] == "f" || line[79:72] == "F") begin
        
        // Convert the hex string to a value
        status = $sscanf(line, "%h", addr_val);
        if (status == 1) begin
          trace_mem[line_count] = addr_val;
          $display("Loaded trace address[%0d]: %h", line_count, addr_val);
          line_count = line_count + 1;
        end
      end
    end
    
    $fclose(file);
    trace_size = line_count;
    $display("Loaded %0d addresses from trace file", trace_size);
    
    // Reset index
    i = 0;
  end

  // Emit addresses from the trace on each clock
  always @(posedge clk) begin
    address <= trace_mem[i];
    i <= i + 1;
    
    // Reset index when at the end of valid trace entries
    if (i >= trace_size - 1)
      i <= 0;
  end
endmodule
