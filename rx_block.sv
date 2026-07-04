module rx_block (
    input  wire        clk,
    input  wire        rstn,
    // Control
    input  wire        rx_enable,
    // Serial input
    input  wire        sdi,
    input  wire        sdi_vld,
    // APB Read side
    input  wire        rd_en,
    output wire [7:0]  rd_data,
    output wire        fifo_full,
    output wire        fifo_empty
);

    //-----------------------------------------------------
    // SIPO
    //-----------------------------------------------------
    wire [7:0] sipo_data;
    wire       sipo_data_vld;

    sipo_vld u_sipo (
        .clk     (clk),
        .rstn    (rstn),
        .sdi     (sdi),
        .sdi_vld (sdi_vld),
        .pdo   (sipo_data),
        .pdo_vld(sipo_data_vld)
    );

    //-----------------------------------------------------
    // RX FIFO
    //-----------------------------------------------------
    sync_fifo #(.DATA_WIDTH(8), .DEPTH(8)) u_rx_fifo (
        .clk     (clk),
        .rst_n   (rstn),
        .wr_en   (sipo_data_vld & rx_enable & ~fifo_full),
        .rd_en   (rd_en & ~fifo_empty),
        .wr_data (sipo_data),
        .full    (fifo_full),
        .empty   (fifo_empty),
        .rd_data (rd_data)
    );

endmodule
