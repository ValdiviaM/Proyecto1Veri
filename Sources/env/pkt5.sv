class pkt5;

// Estado de FIFOs
  rand bit [3:0] rx_fifo_level;
  rand bit [3:0] tx_fifo_level;


  // Niveles de FIFO válidos (depth = 8)
  constraint c_fifo_levels {
    rx_fifo_level <= 4'd8;
    tx_fifo_level <= 4'd8;
    
  }



  
endclass