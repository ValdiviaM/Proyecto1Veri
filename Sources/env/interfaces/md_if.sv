
  interface md_if #(parameter DATA_WIDTH = 32, OFFSET_WIDTH = 2, SIZE_WIDTH = 3);
    logic clk;
    logic reset_n;
    
    logic md_rx_valid;
    logic [DATA_WIDTH-1:0] md_rx_data;
    logic [OFFSET_WIDTH-1:0] md_rx_offset;
    logic [SIZE_WIDTH-1:0] md_rx_size;
    logic md_rx_ready;
    logic md_rx_err;

    logic md_tx_valid;
    logic [DATA_WIDTH-1:0] md_tx_data;
    logic [OFFSET_WIDTH-1:0] md_tx_offset;
    logic [SIZE_WIDTH-1:0] md_tx_size;
    logic md_tx_ready;
    logic md_tx_err;

    clocking transactor_cb @(posedge clk);
      default input #1step output #0;
      output md_rx_valid, md_rx_data, md_rx_offset, md_rx_size;
      input  md_rx_ready, md_rx_err;
      input  md_tx_valid, md_tx_data, md_tx_offset, md_tx_size;
      output  md_tx_ready, md_tx_err;
    endclocking;

    modport DUT (
      input  clk, reset_n, md_rx_valid, md_rx_data, md_rx_offset, md_rx_size, md_tx_ready, md_tx_err,
      output md_rx_ready, md_rx_err, md_tx_valid, md_tx_data, md_tx_offset, md_tx_size
    );

    modport Transactor (
      clocking transactor_cb,
      input clk,
      output reset_n
    );
  endinterface