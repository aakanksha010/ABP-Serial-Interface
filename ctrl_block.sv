module ctrl_block (
    input  wire        clk,
    input  wire        rstn,

    // APB interface side
    input  wire        wr_en,        // APB write enable
    input  wire        rd_en,        // APB read enable
    input  wire [4:0]  addr,         // last 5 bits of APB address
    input  wire [31:0] pwdata,       // write data from APB
    output reg  [31:0] prdata,       // read data to APB

    // TX & RX FIFO status
    input  wire        tx_fifo_full,
    input  wire        tx_fifo_empty,
    input  wire        rx_fifo_full,
    input  wire        rx_fifo_empty,

    // Control outputs
    output wire        tx_enable,
    output wire        rx_enable,

    // Interrupt outputs
    output reg         intr
);

    //---------------------------------------------------
    // Register map (using 5-bit addr)
    //---------------------------------------------------
    localparam ADDR_CTRL   = 5'h00;  // Control Register
    localparam ADDR_STATUS = 5'h04;  // Status Register
    localparam ADDR_IER    = 5'h08;  // Interrupt Enable Register
    localparam ADDR_ISR    = 5'h0C;  // Interrupt Status Register
    // (TXDATA and RXDATA handled in APB interface)

    //---------------------------------------------------
    // Internal Registers
    //---------------------------------------------------
    reg [31:0] ctrl_reg;
    reg [31:0] ier_reg;
    reg [31:0] isr_reg;

    //---------------------------------------------------
    // Control Register (bit 0 = tx_en, bit 1 = rx_en)
    //---------------------------------------------------
    assign tx_enable = ctrl_reg[0];
    assign rx_enable = ctrl_reg[1];

    //---------------------------------------------------
    // Register write logic
    //---------------------------------------------------
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            ctrl_reg <= 32'd0;
            ier_reg  <= 32'd0;
            isr_reg  <= 32'd0;
        end
        else begin
            if (wr_en) begin
                case (addr)
                    ADDR_CTRL:   ctrl_reg <= pwdata;
                    ADDR_IER:    ier_reg  <= pwdata;
                    ADDR_ISR:    isr_reg  <= pwdata; // write 1 to clear bits
                endcase
            end

            // Update ISR based on FIFO events
            if (tx_fifo_empty) isr_reg[0] <= 1'b1; // TX empty interrupt
            else               isr_reg[0] <= 1'b0;

            if (tx_fifo_full)  isr_reg[1] <= 1'b1; // TX full interrupt
            else               isr_reg[1] <= 1'b0;

            if (rx_fifo_empty) isr_reg[2] <= 1'b1; // RX empty interrupt
            else               isr_reg[2] <= 1'b0;

            if (rx_fifo_full)  isr_reg[3] <= 1'b1; // RX full interrupt
            else               isr_reg[3] <= 1'b0;
        end
    end

    //---------------------------------------------------
    // Status Register (read-only)
    //---------------------------------------------------
    wire [31:0] status_reg;
    assign status_reg = {28'd0, rx_fifo_full, rx_fifo_empty, tx_fifo_full, tx_fifo_empty};

    //---------------------------------------------------
    // Register read logic
    //---------------------------------------------------
    always @(*) begin
        case (addr)
            ADDR_CTRL:   prdata = ctrl_reg;
            ADDR_STATUS: prdata = status_reg;
            ADDR_IER:    prdata = ier_reg;
            ADDR_ISR:    prdata = isr_reg;
            default:     prdata = 32'hDEAD_BEEF; // invalid address
        endcase
    end

    //---------------------------------------------------
    // Interrupt generation
    //---------------------------------------------------
    always @(*) begin
        intr = |(isr_reg & ier_reg); // interrupt if enabled and set
    end

endmodule
