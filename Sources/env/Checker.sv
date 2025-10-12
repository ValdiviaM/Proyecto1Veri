'include "pkt4.sv"


class checker #(parameter wdth = 16, parameter dpth = 8);


  // Estado esperado del módulo
  pkt4 expected_state;
  pkt4 actual_state;
  
  // Mailboxes para comunicación
  mailbox #(pkt4) expected_mbx;
  mailbox #(pkt4) actual_mbx;

  // Configuración
  int ALGN_DATA_WIDTH = 32;
  int FIFO_DEPTH = 8;
  
  // Contadores de errores
  int error_count;
  int warning_count;
  
  //Estadisticas
  int transactions_checked;
  int alignment_checks;
  int irq_checks;
  int drop_counter_checks;
  int reset_checks;

  // Control
  bit enable_checking;


  function new(int data_width = 32, int fifo_depth = 8);
    this.ALGN_DATA_WIDTH = data_width;
    this.FIFO_DEPTH = fifo_depth;
    this.error_count = 0;
    this.warning_count = 0;
    this.enable_checking = 1;
    this.transactions_checked = 0;
    this.alignment_checks = 0;
    this.irq_checks = 0;
    this.drop_counter_checks = 0;
    this.reset_checks = 0;
    
    expected_mbx = new();
    actual_mbx = new();

  endfunction

  function void reset_stats();
    error_count = 0;
    warning_count = 0;
    transactions_checked = 0;
    alignment_checks = 0;
    irq_checks = 0;
    drop_counter_checks = 0;
    reset_checks = 0;
  endfunction

//Hay que revisar reset


//Hay que revisar los drops del contador
  function bit check_drop_counter(pkt4 pkt);
    bit pass = 1;
    drop_counter_checks++;

    endfunction

  function bit check_drop_counter_increment(pkt4 before, pkt4 after, bit illegal_transfer);

endfunction

//Hay que revisar alineamiento
  function bit check_alignment_config(pkt4 pkt);
endfunction

  function bit check_rx_transfer_legal(pkt4 pkt);
endfunction


//Hay que revisar interrupciones
  function bit check_irq_output(pkt4 pkt);
endfunction

//Hay que revisar FIFOs
  function bit check_fifo_levels(pkt4 pkt);
endfunction


//Reporte resultados

endclass