'include "pkt4.sv"
'include "pkt5.sv"


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
//function check_reset(pkt4 pkt)
//endfunction


//Hay que revisar los drops del contador
  function bit check_drop_counter(pkt4 pkt);
    bit pass = 1;
    drop_counter_checks++;
    if (!enable_checking) return pass;
    
    // Verificar que el contador no exceda 255
    if (pkt.cnt_drop > 255) begin
      $error("[CHECKER] Drop counter exceeded maximum: CNT_DROP=%0d", pkt.cnt_drop);
      error_count++;
      pass = 0;
    end
    
    // Verificar que cuando está en máximo, el flag esté activo
    if (pkt.cnt_drop == 255 && !pkt.cnt_drop_max) begin
      $error("[CHECKER] Drop counter at max but cnt_drop_max flag not set");
      error_count++;
      pass = 0;
    end
    
    // Verificar que cuando está en máximo, la interrupción esté activa
    if (pkt.cnt_drop == 255 && !pkt.irq_status[4]) begin
      $error("[CHECKER] Drop counter at max but IRQ_MAX_DROP not set");
      error_count++;
      pass = 0;
    end
    
    return pass;
    endfunction

  function bit check_drop_counter_increment(pkt4 before, pkt4 after, bit illegal_transfer);
    bit pass = 1;
    
    if (!enable_checking) return pass;
    
    if (illegal_transfer) begin
      // Verificar incremento del contador (si no está en máximo)
      if (before.cnt_drop < 255) begin
        if (after.cnt_drop !== (before.cnt_drop + 1)) begin
          $error("[CHECKER] Drop counter not incremented: before=%0d, after=%0d", 
                 before.cnt_drop, after.cnt_drop);
          error_count++;
          pass = 0;
        end
      end else begin
        // Si ya está en máximo, debe mantenerse
        if (after.cnt_drop !== 255) begin
          $error("[CHECKER] Drop counter changed from maximum: after=%0d", after.cnt_drop);
          error_count++;
          pass = 0;
        end
      end
    end
    return pass;

endfunction

//Hay que revisar alineamiento
  function bit check_alignment_config(pkt4 pkt);
    bit pass = 1;
    alignment_checks++;
    
    if (!enable_checking) return pass;
    
    // Verificar que SIZE no sea 0
    if (pkt.size == 0) begin
      $error("[CHECKER] Illegal SIZE=0 in configuration");
      error_count++;
      pass = 0;
    end
    
    // Verificar que la combinación (SIZE, OFFSET) sea legal
    if (!pkt.is_alignment_legal(pkt.size, pkt.offset)) begin
      $error("[CHECKER] Illegal alignment configuration: SIZE=%0d, OFFSET=%0d",
             pkt.size, pkt.offset);
      error_count++;
      pass = 0;
    end
    
    // Verificar que OFFSET esté en rango válido
    int max_offset = (ALGN_DATA_WIDTH / 8) - 1;
    if (pkt.offset > max_offset) begin
      $error("[CHECKER] OFFSET out of range: OFFSET=%0d, max=%0d",
             pkt.offset, max_offset);
      error_count++;
      pass = 0;
    end  
    return pass; 
endfunction

  function bit check_rx_transfer_legal(pkt4 pkt);
    bit pass = 1;
    bit is_legal;
    
    if (!enable_checking) return pass;
    
    is_legal = pkt.is_rx_transfer_legal();
    
    // Si la transferencia es ilegal, debe generar error
    if (!is_legal && !pkt.rx_error) begin
      $error("[CHECKER] Illegal RX transfer not flagged as error: rx_offset=%0d, rx_size=%0d",
             pkt.rx_offset, pkt.rx_size);
      error_count++;
      pass = 0;
    end
    
    // Si la transferencia es legal, no debe generar error
    if (is_legal && pkt.rx_error) begin
      $error("[CHECKER] Legal RX transfer flagged as error: rx_offset=%0d, rx_size=%0d",
             pkt.rx_offset, pkt.rx_size);
      error_count++;
      pass = 0;
    end    
    return pass;  
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

//Forma de revisar las transacciones
  function bit check_transaction(pkt4 pkt);
    bit pass = 1;
    
    if (!enable_checking) return pass;
    
    transactions_checked++;
        
    // Verificaciones individuales
    //if (!check_reset(pkt)) pass = 0;
    if (!check_drop_counter(pkt)) pass = 0;
    if (!check_irq_output(pkt)) pass = 0;
    if (!check_alignment_config(pkt)) pass = 0;
    if (!check_fifo_levels(pkt)) pass = 0;
    
    if (pkt.rx_valid)
      if (!check_rx_transfer_legal(pkt)) pass = 0;
    
    
    return pass;
  endfunction

//Comparar paquetes
  function bit compare_packets(pkt4 expected, pkt4 actual, string context = "");
    bit pass = 1;
    
    if (!enable_checking) return pass;
    
    
    // Comparar contador de drops
    if (expected.cnt_drop !== actual.cnt_drop) begin
      $error("[CHECKER] %s: CNT_DROP mismatch: expected=%0d, actual=%0d",
             context, expected.cnt_drop, actual.cnt_drop);
      error_count++;
      pass = 0;
    end
    
    // Comparar estado de interrupciones
    if (expected.irq_status !== actual.irq_status) begin
      $error("[CHECKER] %s: IRQ_STATUS mismatch: expected=0x%02h, actual=0x%02h",
             context, expected.irq_status, actual.irq_status);
      error_count++;
      pass = 0;
    end
    
    // Comparar configuración de alineamiento
    if (expected.size !== actual.size) begin
      $error("[CHECKER] %s: SIZE mismatch: expected=%0d, actual=%0d",
             context, expected.size, actual.size);
      error_count++;
      pass = 0;
    end
    
    if (expected.offset !== actual.offset) begin
      $error("[CHECKER] %s: OFFSET mismatch: expected=%0d, actual=%0d",
             context, expected.offset, actual.offset);
      error_count++;
      pass = 0;
    end
    
    // Comparar niveles de FIFO
    if (expected.rx_fifo_level !== actual.rx_fifo_level) begin
      $error("[CHECKER] %s: RX_FIFO_LEVEL mismatch: expected=%0d, actual=%0d",
             context, expected.rx_fifo_level, actual.rx_fifo_level);
      error_count++;
      pass = 0;
    end
    
    if (expected.tx_fifo_level !== actual.tx_fifo_level) begin
      $error("[CHECKER] %s: TX_FIFO_LEVEL mismatch: expected=%0d, actual=%0d",
             context, expected.tx_fifo_level, actual.tx_fifo_level);
      error_count++;
      pass = 0;
    end
    
    if (pass && verbose_mode)
      $display("[CHECKER] Packet comparison PASSED: %s", context);
    
    return pass;
  endfunction



//Reporte resultados
 function void report(string prefix = "");
    $display("========================================");
    $display("%s ALIGNER CHECKER REPORT", prefix);
    $display("========================================");
    $display("Transactions checked:    %0d", transactions_checked);
    $display("Alignment checks:        %0d", alignment_checks);
    $display("IRQ checks:              %0d", irq_checks);
    $display("Drop counter checks:     %0d", drop_counter_checks);
    $display("Reset checks:            %0d", reset_checks);
    $display("----------------------------------------");
    $display("Errors found:            %0d", error_count);
    $display("Warnings:                %0d", warning_count);
    $display("========================================");
    
    if (error_count == 0) begin
      $display("%s ALL CHECKS PASSED!", prefix);
    end else begin
      $display("%s CHECKS FAILED with %0d errors", prefix, error_count);
    end
    $display("========================================");
  endfunction




//Funciones auxiliares del reporte
  function bit all_checks_passed();
    return (error_count == 0);
  endfunction
  
  function int get_error_count();
    return error_count;
  endfunction
  
  function int get_warning_count();
    return warning_count;
  endfunction



endclass