module piso_vld (
    input  wire       clk,
    input  wire       rstn,
    input  wire [7:0] wdata,
    input  wire       wvld,
    output reg        wready,
    output reg        sdo_vld,
    output wire       sdo
);

  reg [7:0] shift_reg;
  reg [3:0] count;
  reg [1:0] pr_state, next_state;

  localparam IDLE  = 2'd0,
             LOAD  = 2'd1,
             SHIFT = 2'd2;

  // State register
  always @(posedge clk or negedge rstn) begin
    if (!rstn)
      pr_state <= IDLE;
    else
      pr_state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = pr_state;
    sdo_vld    = 1'b0;
    wready     = 1'b0;

    case (pr_state)
      IDLE: begin
        wready = 1'b1;
        if (wvld) next_state = LOAD;
      end

      LOAD: next_state = SHIFT;

      SHIFT: begin
        if (count < 8) begin
          sdo_vld = 1'b1;
          next_state = SHIFT;
        end else
          next_state = IDLE;
      end
    endcase
  end

  // Data and counter
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      shift_reg <= 8'd0;
      count     <= 0;
    end else begin
      case (pr_state)
        LOAD: begin
          shift_reg <= wdata;
          count     <= 0;
        end
        SHIFT: if (count < 8) begin
          shift_reg <= shift_reg >> 1;
          count     <= count + 1;
        end
      endcase
    end
  end

  assign sdo = shift_reg[0];

endmodule
