module tx_block (
    input  wire        clk,
    input  wire        rstn,
    // Control
    input  wire        tx_enable,
    // APB Write side
    input  wire        wr_en,
    input  wire [7:0]  wr_data,
    output wire        fifo_full,
    output wire        fifo_empty,
    // Serial output
    output wire        sdo,
    output wire        sdo_vld
);

    //-----------------------------------------------------
    // Internal TX FIFO
    //-----------------------------------------------------
    wire       tx_fifo_rd_en;
    wire [7:0] tx_fifo_rdata;

    sync_fifo #(.DATA_WIDTH(8), .DEPTH(8)) u_tx_fifo (
        .clk     (clk),
        .rst_n   (rstn),
        .wr_en   (wr_en & tx_enable & ~fifo_full),
        .rd_en   (tx_fifo_rd_en),
        .wr_data (wr_data),
        .full    (fifo_full),
        .empty   (fifo_empty),
        .rd_data (tx_fifo_rdata)
    );

    //-----------------------------------------------------
    // PISO
    //-----------------------------------------------------
    wire piso_wready;

    piso_vld u_piso (
        .clk    (clk),
        .rstn   (rstn),
        .wdata  (tx_fifo_rdata),
        .wvld   (~fifo_empty & tx_enable), // only shift if enabled
        .wready (piso_wready),
        .sdo_vld(sdo_vld),
        .sdo    (sdo)
    );

    //-----------------------------------------------------
    // Control FIFO pop
    //-----------------------------------------------------
    assign tx_fifo_rd_en = (~fifo_empty & tx_enable & piso_wready);

endmodule
