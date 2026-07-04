module sipo_vld (
  input  wire clk,
  input  wire rstn,
  input  wire sdi,
  input  wire sdi_vld,
  output reg [7:0] pdo,
  output reg       pdo_vld
);

  reg [2:0] count;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      pdo     <= 8'd0;
      count   <= 3'd0;
      pdo_vld <= 1'b0;
    end else begin
      if (sdi_vld) begin
        pdo   <= {sdi, pdo[7:1]};
        count <= count + 1;
      end

      if (count == 3'd7)
        pdo_vld <= 1'b1;
      else
        pdo_vld <= 1'b0;
    end
  end

endmodule
