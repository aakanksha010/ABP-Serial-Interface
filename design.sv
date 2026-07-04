// apb_serial_top.v
// Top-level APB -> serial interface (wires up ctrl_block, tx_block, rx_block)
//
// Ports
// - APB: PCLK, PRESETn, PSEL, PENABLE, PWRITE, PADDR[31:0], PWDATA[31:0], PRDATA[31:0], PREADY
// - Serial: sdo, sdo_vld (tx out), sdi, sdi_vld (rx in)
// - irq: interrupt output

// ---------------------------------------------------------------------
// Includes (EDA Playground will look for these in the same tab or other tabs)
// ---------------------------------------------------------------------
`include "ctrl_block.sv"
`include "tx_block.sv"
`include "rx_block.sv"
`include "sync_fifo.sv"
`include "piso_vld.sv"
`include "sipo_vld.sv"

// ---------------------------------------------------------------------
// Top-level APB Serial Interface
// ---------------------------------------------------------------------
module apb_serial_top (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PADDR,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire        PREADY,

    // serial I/O
    output wire        sdo,
    output wire        sdo_vld,
    input  wire        sdi,
    input  wire        sdi_vld,

    // interrupt
    output wire        irq
);

    // Always ready
    assign PREADY = 1'b1;

    // Local convenience
    wire [4:0] addr5 = PADDR[4:0];
    wire apb_write = PSEL & PENABLE & PWRITE;
    wire apb_read  = PSEL & PENABLE & ~PWRITE;

    // -----------------------------------------------------------------
    // Control block
    // -----------------------------------------------------------------
    wire        ctrl_tx_en;
    wire        ctrl_rx_en;
    wire [31:0] ctrl_prdata;
    wire        ctrl_intr;

    wire tx_fifo_full, tx_fifo_empty;
    wire rx_fifo_full, rx_fifo_empty;

    reg ctrl_wr_strobe;
    reg ctrl_rd_strobe;

    ctrl_block u_ctrl_block (
        .clk        (PCLK),
        .rstn       (PRESETn),
        .wr_en      (ctrl_wr_strobe),
        .rd_en      (ctrl_rd_strobe),
        .addr       (addr5),
        .pwdata     (PWDATA),
        .prdata     (ctrl_prdata),
        .tx_fifo_full (tx_fifo_full),
        .tx_fifo_empty(tx_fifo_empty),
        .rx_fifo_full (rx_fifo_full),
        .rx_fifo_empty(rx_fifo_empty),
        .tx_enable  (ctrl_tx_en),
        .rx_enable  (ctrl_rx_en),
        .intr       (ctrl_intr)
    );

    // -----------------------------------------------------------------
    // TX block
    // -----------------------------------------------------------------
    reg  tx_wr_en_reg;
    reg  [7:0] tx_wr_data_reg;

    tx_block u_tx_block (
        .clk        (PCLK),
        .rstn       (PRESETn),
        .tx_enable  (ctrl_tx_en),
        .wr_en      (tx_wr_en_reg),
        .wr_data    (tx_wr_data_reg),
        .fifo_full  (tx_fifo_full),
        .fifo_empty (tx_fifo_empty),
        .sdo        (sdo),
        .sdo_vld    (sdo_vld)
    );

    // -----------------------------------------------------------------
    // RX block
    // -----------------------------------------------------------------
    reg rx_rd_en_reg;
    wire [7:0] rx_rd_data_wire;

    rx_block u_rx_block (
        .clk        (PCLK),
        .rstn       (PRESETn),
        .rx_enable  (ctrl_rx_en),
        .sdi        (sdi),
        .sdi_vld    (sdi_vld),
        .rd_en      (rx_rd_en_reg),
        .rd_data    (rx_rd_data_wire),
        .fifo_full  (rx_fifo_full),
        .fifo_empty (rx_fifo_empty)
    );

    // -----------------------------------------------------------------
    // APB register strobes
    // -----------------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            ctrl_wr_strobe <= 1'b0;
            ctrl_rd_strobe <= 1'b0;
        end else begin
            ctrl_wr_strobe <= 1'b0;
            ctrl_rd_strobe <= 1'b0;
            if (apb_write) begin
                if ((addr5 == 5'h00) || (addr5 == 5'h10) || (addr5 == 5'h14))
                    ctrl_wr_strobe <= 1'b1;
            end
            if (apb_read) begin
                if ((addr5 == 5'h00) || (addr5 == 5'h04) || (addr5 == 5'h10) || (addr5 == 5'h14))
                    ctrl_rd_strobe <= 1'b1;
            end
        end
    end

    // TXDATA write
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            tx_wr_en_reg <= 1'b0;
            tx_wr_data_reg <= 8'h00;
        end else begin
            tx_wr_en_reg <= 1'b0;
            if (apb_write && (addr5 == 5'h08)) begin
                if (ctrl_tx_en && ~tx_fifo_full) begin
                    tx_wr_en_reg <= 1'b1;
                    tx_wr_data_reg <= PWDATA[7:0];
                end
            end
        end
    end

    // RXDATA read
    reg [7:0] rx_read_data_reg;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            rx_rd_en_reg <= 1'b0;
            rx_read_data_reg <= 8'h00;
        end else begin
            rx_rd_en_reg <= 1'b0;
            if (apb_read && (addr5 == 5'h0C)) begin
                if (ctrl_rx_en && ~rx_fifo_empty) begin
                    rx_rd_en_reg <= 1'b1;
                    rx_read_data_reg <= rx_rd_data_wire;
                end else begin
                    rx_read_data_reg <= 8'h00;
                end
            end
        end
    end

    // APB read mux
    always @(*) begin
        PRDATA = 32'h0;
        if (apb_read) begin
            case (addr5)
                5'h00: PRDATA = ctrl_prdata;
                5'h04: PRDATA = ctrl_prdata;
                5'h08: PRDATA = 32'h0;
                5'h0C: PRDATA = {24'h0, rx_read_data_reg};
                5'h10: PRDATA = ctrl_prdata;
                5'h14: PRDATA = ctrl_prdata;
                default: PRDATA = 32'h0;
            endcase
        end
    end

    // IRQ out
    assign irq = ctrl_intr;

endmodule
