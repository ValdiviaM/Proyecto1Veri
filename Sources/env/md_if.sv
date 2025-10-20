interface md_if #(
  parameter DATA_WIDTH   = 32,
  parameter OFFSET_WIDTH = 2,
  parameter SIZE_WIDTH   = 3
);
  // Señal de reloj, fundamental para la sincronización
  logic clk;

  // --- Canales de Señales ---
  // RX channel (input to DUT)
  logic                   md_rx_valid;
  logic [DATA_WIDTH-1:0]   md_rx_data;
  // ... (resto de señales rx)
  logic                    md_rx_ready;
  logic                    md_rx_err;

  // TX channel (output from DUT)
  logic                   md_tx_valid;
  logic [DATA_WIDTH-1:0]   md_tx_data;
  // ... (resto de señales tx)
  logic                    md_tx_ready;
  logic                    md_tx_err;

  // Clocking block para el Testbench (Transactor)
  clocking transactor_cb @(posedge clk);
    default input #1step output #0;

    // El TB conduce el canal RX hacia el DUT
    output md_rx_valid, md_rx_data, md_rx_offset, md_rx_size;
    input  md_rx_ready, md_rx_err;

    // El TB recibe del canal TX del DUT
    input  md_tx_valid, md_tx_data, md_tx_offset, md_tx_size;
    output md_tx_ready, md_tx_err;
  endclocking;

  // --- Modports ---
  modport DUT (
    input  clk, 
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
    clocking transactor_cb, 
    input clk              // Exportamos el reloj para delays genéricos
  );

endinterface