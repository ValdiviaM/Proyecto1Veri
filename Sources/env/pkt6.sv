  class pkt6;
    
  
  // Datos de entrada (RX)
  rand bit [31:0] rx_data;
  rand bit [1:0]  rx_offset;
  rand bit [2:0]  rx_size;
  bit             rx_valid;
  bit             rx_ready;
  bit             rx_error;
  
  // Datos de salida (TX)
  bit [31:0] tx_data;
  bit [1:0]  tx_offset;
  bit [2:0]  tx_size;
  bit        tx_valid;
  bit        tx_ready;

  endclass
