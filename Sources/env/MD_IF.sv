interface md_if #(
  parameter DATA_WIDTH   = 32,
  parameter OFFSET_WIDTH = 2,
  parameter SIZE_WIDTH   = 3
);

  // RX channel (input to DUT)
  logic                   md_rx_valid;
  logic [DATA_WIDTH-1:0]   md_rx_data;
  logic [OFFSET_WIDTH-1:0] md_rx_offset;
  logic [SIZE_WIDTH-1:0]   md_rx_size;
  logic                    md_rx_ready;
  logic                    md_rx_err;

  // TX channel (output from DUT)
  logic                   md_tx_valid;
  logic [DATA_WIDTH-1:0]   md_tx_data;
  logic [OFFSET_WIDTH-1:0] md_tx_offset;
  logic [SIZE_WIDTH-1:0]   md_tx_size;
  logic                    md_tx_ready;
  logic                    md_tx_err;

  // Modports
  modport DUT (
    input  md_rx_valid,
    input  md_rx_data,
    input  md_rx_offset,
    input  md_rx_size,
    output md_rx_ready,
    output md_rx_err,

    output md_tx_valid,
    output md_tx_data,
    output md_tx_offset,
    output md_tx_size,
    input  md_tx_ready,
    input  md_tx_err
  );

  modport Transactor (
    output md_rx_valid,
    output md_rx_data,
    output md_rx_offset,
    output md_rx_size,
    input  md_rx_ready,
    input  md_rx_err,

    input  md_tx_valid,
    input  md_tx_data,
    input  md_tx_offset,
    input  md_tx_size,
    output md_tx_ready,
    output md_tx_err
  );

endinterface
