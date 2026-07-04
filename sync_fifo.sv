module sync_fifo
  #(
    parameter DATA_WIDTH=8,
    parameter DEPTH=8
  )
  (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 wr_en,
    input  wire                 rd_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                 full,
    output wire                 empty,
    output wire [DATA_WIDTH-1:0] rd_data
  );

  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  reg [$clog2(DEPTH):0] wr_ptr, rd_ptr;

  wire ptr_eql;
  wire dir;

  // Write logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      wr_ptr <= 0;
    else if (wr_en && !full) begin
      mem[wr_ptr[$clog2(DEPTH)-1:0]] <= wr_data;
      wr_ptr <= wr_ptr + 1;
    end
  end

  // Read logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      rd_ptr <= 0;
    else if (rd_en && !empty)
      rd_ptr <= rd_ptr + 1;
  end

  assign rd_data = mem[rd_ptr[$clog2(DEPTH)-1:0]];
  assign ptr_eql = (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0]);
  assign dir     = wr_ptr[$clog2(DEPTH)] ^ rd_ptr[$clog2(DEPTH)];
  assign empty   = ~dir && ptr_eql;
  assign full    =  dir && ptr_eql;

endmodule
