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
    bit pass = 1;
    bit expected_irq;
    irq_checks++;
    
    if (!enable_checking) return pass;
    
    // IRQ output debe ser OR de (status & enable)
    expected_irq = |(pkt.irq_status & pkt.irq_enable);
    
    if (pkt.irq_out !== expected_irq) begin
      $error("[CHECKER] IRQ output mismatch: actual=%b, expected=%b (status=0x%02h, enable=0x%02h)",
             pkt.irq_out, expected_irq, pkt.irq_status, pkt.irq_enable);
      error_count++;
      pass = 0;
    end
    
  endfunction
endfunction

function bit check_irq_sticky(pkt4 pkt, pkt4::irq_type_e irq_type);
    bit pass = 1;
    
    if (!enable_checking) return pass;
    
    // Verificar que la interrupción permanezca activa (sticky) hasta que se limpie
    case (irq_type)
      pkt4::IRQ_RX_FIFO_EMPTY: begin
        if (pkt.irq_status[0] && pkt.rx_fifo_level > 0 && !pkt.rx_fifo_empty_event) begin
            $display("[CHECKER] IRQ_RX_FIFO_EMPTY correctly sticky");
      end
      
      pkt4::IRQ_RX_FIFO_FULL: begin
        if (pkt.irq_status[1] && pkt.rx_fifo_level < FIFO_DEPTH && !pkt.rx_fifo_full_event) begin
          $display("[CHECKER] IRQ_RX_FIFO_FULL correctly sticky");
      end
      
      pkt4::IRQ_TX_FIFO_EMPTY: begin
        if (pkt.irq_status[2] && pkt.tx_fifo_level > 0 && !pkt.tx_fifo_empty_event) begin
          $display("[CHECKER] IRQ_TX_FIFO_EMPTY correctly sticky");
      end
      
      pkt4::IRQ_TX_FIFO_FULL: begin
        if (pkt.irq_status[3] && pkt.tx_fifo_level < FIFO_DEPTH && !pkt.tx_fifo_full_event) begin
          $display("[CHECKER] IRQ_TX_FIFO_FULL correctly sticky");
      end
      
      pkt4::IRQ_MAX_DROP: begin
        if (pkt.irq_status[4] && pkt.cnt_drop < 255 && !pkt.max_drop_event) begin
          $display("[CHECKER] IRQ_MAX_DROP correctly sticky");
        
      end
    endcase
    
    return pass;
  endfunction




//Hay que revisar FIFOs
  function bit check_fifo_levels(pkt4 pkt);
    bit pass = 1;
    
    if (!enable_checking) return pass;
    
    // Verificar que los niveles de FIFO no excedan la profundidad
    if (pkt.rx_fifo_level > FIFO_DEPTH) begin
      $error("[CHECKER] RX FIFO level exceeds depth: level=%0d, depth=%0d",
             pkt.rx_fifo_level, FIFO_DEPTH);
      error_count++;
      pass = 0;
    end
    
    if (pkt.tx_fifo_level > FIFO_DEPTH) begin
      $error("[CHECKER] TX FIFO level exceeds depth: level=%0d, depth=%0d",
             pkt.tx_fifo_level, FIFO_DEPTH);
      error_count++;
      pass = 0;
    end
    
    // Verificar coherencia con interrupciones de FIFO vacío
    if (pkt.rx_fifo_level == 0 && pkt.rx_fifo_empty_event) begin
      if (!pkt.irq_status[0]) begin
        $error("[CHECKER] RX FIFO empty but IRQ not set");
        error_count++;
        pass = 0;
      end
    end
    
    if (pkt.tx_fifo_level == 0 && pkt.tx_fifo_empty_event) begin
      if (!pkt.irq_status[2]) begin
        $error("[CHECKER] TX FIFO empty but IRQ not set");
        error_count++;
        pass = 0;
      end
    end
    
    // Verificar coherencia con interrupciones de FIFO lleno
    if (pkt.rx_fifo_level == FIFO_DEPTH && pkt.rx_fifo_full_event) begin
      if (!pkt.irq_status[1]) begin
        $error("[CHECKER] RX FIFO full but IRQ not set");
        error_count++;
        pass = 0;
      end
    end
    
    if (pkt.tx_fifo_level == FIFO_DEPTH && pkt.tx_fifo_full_event) begin
      if (!pkt.irq_status[3]) begin
        $error("[CHECKER] TX FIFO full but IRQ not set");
        error_count++;
        pass = 0;
      end
    end
endfunction


//Reporte resultados

endclass