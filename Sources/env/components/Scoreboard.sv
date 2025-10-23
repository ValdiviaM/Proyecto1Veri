typedef class environment;

class scoreboard;
  import dut_params_pkg::*;

  string name = "Scoreboard";

  //--- Mailboxes ---//
  mailbox #(md_packet)        rx_mon_mbx;
  mailbox #(md_packet)        tx_mon_mbx;
  mailbox #(apb_transaction)  apb_mon_mbx;

  //--- Componentes de utilidad ---//
  protected checker    m_checker;
  protected csv_logger m_logger;

  protected environment m_env;
  
  //--- Colas internas y Modelo del DUT ---//
  protected md_packet  m_expected_q[$];
  protected byte       m_byte_buffer_q[$]; // Búfer de bytes para el modelo de alineación

  //--- Shadow Registers (Modelo del estado del DUT) ---//
  protected bit [ALGN_SIZE_WIDTH-1:0]   shadow_ctrl_size   = 1;
  protected bit [ALGN_OFFSET_WIDTH-1:0] shadow_ctrl_offset = 0;
  protected int unsigned                shadow_cnt_drop    = 0;
  protected bit                         shadow_cnt_drop_maxed = 0;

 //--- Shadow FIFO Level Tracking ---//
  protected int unsigned shadow_rx_fifo_level = 0;
  protected int unsigned shadow_tx_fifo_level = 0;

  //--- Shadow IRQ Status Bits (W1C - Sticky) ---//
  protected bit shadow_irq_rx_fifo_empty = 0;
  protected bit shadow_irq_rx_fifo_full  = 0;
  protected bit shadow_irq_tx_fifo_empty = 0;
  protected bit shadow_irq_tx_fifo_full  = 0;
  protected bit shadow_irq_max_drop      = 0;
  
  //--- Shadow IRQ Enable Bits (RW) ---//
  protected bit shadow_irqen_rx_fifo_empty = 0;
  protected bit shadow_irqen_rx_fifo_full  = 0;
  protected bit shadow_irqen_tx_fifo_empty = 0;
  protected bit shadow_irqen_tx_fifo_full  = 0;
  protected bit shadow_irqen_max_drop      = 0;

  //--- Contadores para el reporte final ---//
  int unsigned match_count = 0;
  int unsigned mismatch_count = 0;
  
int unsigned apb_writes_processed = 0;
int unsigned apb_reads_processed = 0;
int unsigned apb_errors_expected = 0;
int unsigned legal_packets_received = 0;


  //--- Constructor ---//
  function new(mailbox #(md_packet) rx_mon_mbx,
               mailbox #(md_packet) tx_mon_mbx,
               mailbox #(apb_transaction) apb_mon_mbx,
               environment m_env);
    this.rx_mon_mbx  = rx_mon_mbx;
    this.tx_mon_mbx  = tx_mon_mbx;
    this.apb_mon_mbx = apb_mon_mbx;
    this.m_env = m_env; // asigno handle del env
    
    m_checker = new();
    m_logger  = new("simulation_log.csv"); 
  endfunction

  //--- Tarea Principal ---//
  task run();
    $display("[%s] El scoreboard ha comenzado.", name);
    fork
      process_inputs_and_predict();
      process_outputs_and_check();
      process_apb_config();
    join
  endtask
  
  //--- Tareas de Proceso ---//

  // CAMBIO CLAVE: Esta tarea ahora replica la lógica del DUT para descartar paquetes.
  // NOTA: ya NO reporta al environment aquí; el reporting de progreso se hace cuando
  // se verifica/loggea una salida (output) en process_outputs_and_check.
  protected task process_inputs_and_predict();
    forever begin
      md_packet rx_pkt;
      bit is_pkt_legal;

      // 1. Obtiene el paquete de entrada tal como lo vio el monitor
      rx_mon_mbx.get(rx_pkt);
      
      // 2. REPLICA LA LÓGICA DEL 'cfs_rx_ctrl' PARA DETERMINAR SI ES LEGAL
      if (rx_pkt.size == 0 || ((((ALGN_DATA_WIDTH / 8) + rx_pkt.offset) % rx_pkt.size) != 0)) begin
        is_pkt_legal = 0;
      end else begin
        is_pkt_legal = 1;
      end

      // 3. Actúa según el resultado, igual que lo haría el DUT
      if (!is_pkt_legal) begin
        // El DUT habría descartado este paquete y aumentado su contador interno.
        shadow_cnt_drop++;
        $display("[%s] Modelo: Paquete de entrada ILEGAL detectado y descartado (size=%0d, offset=%0d).", name, rx_pkt.size, rx_pkt.offset);
      end else begin
        legal_packets_received++;
        
        // Update shadow RX FIFO level (simplified - assumes FIFO has room)
        if (shadow_rx_fifo_level < FIFO_DEPTH) begin
          shadow_rx_fifo_level++;
        end
        
        $display("[%s] Modelo: Paquete de entrada LEGAL aceptado. Pasando al predictor...(size=%0d, offset=%0d). RX FIFO level: %0d", 
                 name, rx_pkt.size, rx_pkt.offset, shadow_rx_fifo_level);
        
        //Predecir salidad basada en el paquete lega
        predict_dut_output(rx_pkt);

        // Simular FIFO consumida por el controlador
        if (shadow_rx_fifo_level > 0) begin
          shadow_rx_fifo_level--;
        end
      end

      // <-- IMPORTANTE: ya NO reportamos el paquete procesado al environment aquí.
    end
  endtask

  protected task process_outputs_and_check();
    forever begin
      md_packet actual_pkt, expected_pkt;
      bit match;
      
      // Bloquea hasta que el monitor de salida (TX) envíe un paquete
      tx_mon_mbx.get(actual_pkt);
      
      if (m_expected_q.size() == 0) begin
        $error("[%s] ¡Paquete de salida inesperado recibido del DUT! La cola de predicciones estaba vacía. Data: %h", name, actual_pkt.data);
        mismatch_count++;
        // Aun así queremos loggear el evento como mismatch "sin esperado"
        // Creamos un expected_pkt vacío para registrar en CSV (si procede)
        expected_pkt = new();
        expected_pkt.size = 0;
        expected_pkt.offset = 0;
        expected_pkt.data = '0;
        m_logger.log_entry(0, actual_pkt, expected_pkt);

        // Reportamos que se procesó (salida consumida y loggeada)
        m_env.report_output_processed();
        continue;
      end
      
      expected_pkt = m_expected_q.pop_front();
      
      match = m_checker.compare(expected_pkt, actual_pkt);
      
      if (match) begin
        $display("[%s] *** PACKET MATCH ***", name);
        match_count++;
      end else begin
        mismatch_count++;
        // El checker (no provisto) debería imprimir los detalles del error.
      end
      
      // Loguea la comparación en el CSV (task)
      m_logger.log_entry(match, actual_pkt, expected_pkt);

      // Reporta solo cuando se ha consumido/verificado y loggeado la salida.
      m_env.report_output_processed();
    end
  endtask
  

protected task process_apb_config();
  forever begin
    apb_transaction tx;
    bit [31:0] expected_rdata;
    bit [31:0] expected_irqen;
    bit [31:0] expected_irq;
    bit expect_error;

    apb_mon_mbx.get(tx);
    
    case (tx.addr)
      `ADDR_CTRL: begin
        if (tx.op == APB_WRITE) begin
          apb_writes_processed++;
          expect_error = check_ctrl_write_validity(tx.wdata);
          
          if (expect_error) begin
            apb_errors_expected++;
            if (!tx.error) begin
              $error("[%s] APB: Expected ERROR on CTRL write not seen! wdata=%h", name, tx.wdata);
            end else begin
              $display("[%s] APB: CTRL write ERROR correctly generated.", name);
            end
          end else begin
            // Valid write - update shadow registers
            shadow_ctrl_size = tx.wdata[LSB_CTRL_SIZE +: ALGN_SIZE_WIDTH];
            shadow_ctrl_offset = tx.wdata[LSB_CTRL_OFFSET +: ALGN_OFFSET_WIDTH];
            
            // Check CLR bit
            if (tx.wdata[LSB_CTRL_CLR]) begin
              shadow_cnt_drop = 0;
              shadow_cnt_drop_maxed = 0;
              $display("[%s] APB: CTRL.CLR written - drop counter reset to 0.", name);
            end
            
            $display("[%s] APB: CTRL updated - SIZE=%0d, OFFSET=%0d", 
                     name, shadow_ctrl_size, shadow_ctrl_offset);
          end
        end else begin // READ
          apb_reads_processed++;
          $display("[%s] APB: CTRL read - value=%h", name, tx.rdata);
        end
      end
      
      `ADDR_STATUS: begin
        if (tx.op == APB_WRITE) begin
          apb_writes_processed++;
          // Writing to STATUS should generate error
          apb_errors_expected++;
          if (!tx.error) begin
            $error("[%s] APB: Expected ERROR on STATUS write not seen!", name);
          end else begin
            $display("[%s] APB: STATUS write ERROR correctly generated.", name);
          end
        end else begin // READ
          apb_reads_processed++;
          expected_rdata = build_expected_status();
          
          if (tx.rdata !== expected_rdata) begin
            $warning("[%s] APB: STATUS read mismatch!", name);
            $warning("        Expected: %h (CNT_DROP=%0d, RX_LVL=%0d, TX_LVL=%0d)", 
                     expected_rdata, shadow_cnt_drop, shadow_rx_fifo_level, shadow_tx_fifo_level);
            $warning("        Actual:   %h", tx.rdata);
          end else begin
            $display("[%s] APB: STATUS read MATCH - CNT_DROP=%0d, RX_LVL=%0d, TX_LVL=%0d", 
                     name, shadow_cnt_drop, shadow_rx_fifo_level, shadow_tx_fifo_level);
          end
        end
      end
      
      `ADDR_IRQEN: begin
        if (tx.op == APB_WRITE) begin
          apb_writes_processed++;
          // Update shadow enable bits
          shadow_irqen_rx_fifo_empty = tx.wdata[LSB_IRQEN_RX_FIFO_EMPTY];
          shadow_irqen_rx_fifo_full  = tx.wdata[LSB_IRQEN_RX_FIFO_FULL];
          shadow_irqen_tx_fifo_empty = tx.wdata[LSB_IRQEN_TX_FIFO_EMPTY];
          shadow_irqen_tx_fifo_full  = tx.wdata[LSB_IRQEN_TX_FIFO_FULL];
          shadow_irqen_max_drop      = tx.wdata[LSB_IRQEN_MAX_DROP];
          
          $display("[%s] APB: IRQEN updated - RX_EMPTY=%b, RX_FULL=%b, TX_EMPTY=%b, TX_FULL=%b, MAX_DROP=%b",
                   name, shadow_irqen_rx_fifo_empty, shadow_irqen_rx_fifo_full,
                   shadow_irqen_tx_fifo_empty, shadow_irqen_tx_fifo_full, shadow_irqen_max_drop);
        end else begin // READ
          apb_reads_processed++;
          expected_irqen = 0;
          expected_irqen[LSB_IRQEN_RX_FIFO_EMPTY] = shadow_irqen_rx_fifo_empty;
          expected_irqen[LSB_IRQEN_RX_FIFO_FULL]  = shadow_irqen_rx_fifo_full;
          expected_irqen[LSB_IRQEN_TX_FIFO_EMPTY] = shadow_irqen_tx_fifo_empty;
          expected_irqen[LSB_IRQEN_TX_FIFO_FULL]  = shadow_irqen_tx_fifo_full;
          expected_irqen[LSB_IRQEN_MAX_DROP]      = shadow_irqen_max_drop;
          
          if (tx.rdata !== expected_irqen) begin
            $warning("[%s] APB: IRQEN read mismatch! Expected: %h, Actual: %h", 
                     name, expected_irqen, tx.rdata);
          end else begin
            $display("[%s] APB: IRQEN read MATCH - value=%h", name, tx.rdata);
          end
        end
      end
      
      `ADDR_IRQ: begin
        if (tx.op == APB_WRITE) begin
          apb_writes_processed++;
          // W1C: Clear bits where wdata has 1
          if (tx.wdata[LSB_IRQ_RX_FIFO_EMPTY]) shadow_irq_rx_fifo_empty = 0;
          if (tx.wdata[LSB_IRQ_RX_FIFO_FULL])  shadow_irq_rx_fifo_full  = 0;
          if (tx.wdata[LSB_IRQ_TX_FIFO_EMPTY]) shadow_irq_tx_fifo_empty = 0;
          if (tx.wdata[LSB_IRQ_TX_FIFO_FULL])  shadow_irq_tx_fifo_full  = 0;
          if (tx.wdata[LSB_IRQ_MAX_DROP])      shadow_irq_max_drop      = 0;
          
          $display("[%s] APB: IRQ W1C write - clearing bits=%h", name, tx.wdata);
        end else begin // READ
          apb_reads_processed++;
          expected_irq = 0;
          expected_irq[LSB_IRQ_RX_FIFO_EMPTY] = shadow_irq_rx_fifo_empty;
          expected_irq[LSB_IRQ_RX_FIFO_FULL]  = shadow_irq_rx_fifo_full;
          expected_irq[LSB_IRQ_TX_FIFO_EMPTY] = shadow_irq_tx_fifo_empty;
          expected_irq[LSB_IRQ_TX_FIFO_FULL]  = shadow_irq_tx_fifo_full;
          expected_irq[LSB_IRQ_MAX_DROP]      = shadow_irq_max_drop;
          
          if (tx.rdata !== expected_irq) begin
            $error("[%s] APB: IRQ read mismatch!", name);
            $error("        Expected: %h (RX_EMPTY=%b, RX_FULL=%b, TX_EMPTY=%b, TX_FULL=%b, MAX_DROP=%b)",
                   expected_irq, shadow_irq_rx_fifo_empty, shadow_irq_rx_fifo_full,
                   shadow_irq_tx_fifo_empty, shadow_irq_tx_fifo_full, shadow_irq_max_drop);
            $error("        Actual:   %h", tx.rdata);
          end else begin
            $display("[%s] APB: IRQ read MATCH - value=%h", name, tx.rdata);
          end
        end
      end
      
      default: begin
        // Access to unmapped address should return error
        apb_errors_expected++;
        if (!tx.error) begin
          $error("[%s] APB: Expected ERROR on unmapped address %h not seen!", name, tx.addr);
        end else begin
          $display("[%s] APB: Unmapped address %h correctly generated ERROR.", name, tx.addr);
        end
      end
    endcase
  end
endtask

// Check if CTRL write is valid
protected function bit check_ctrl_write_validity(bit [31:0] wdata);
  bit [ALGN_SIZE_WIDTH-1:0] new_size;
  bit [ALGN_OFFSET_WIDTH-1:0] new_offset;
  
  new_size = wdata[LSB_CTRL_SIZE +: ALGN_SIZE_WIDTH];
  new_offset = wdata[LSB_CTRL_OFFSET +: ALGN_OFFSET_WIDTH];
  
  // SIZE = 0 is illegal
  if (new_size == 0) return 1;
  
  // Check if (SIZE, OFFSET) combination is legal
  if ((((ALGN_DATA_WIDTH / 8) + new_offset) % new_size) != 0) return 1;
  
  return 0; // Valid write
endfunction

  // Configuracion de los valores del STATUS register 
  protected function bit [31:0] build_expected_status();
    bit [31:0] status = 0;
    status[LSB_STATUS_CNT_DROP +: STATUS_CNT_DROP_WIDTH] = shadow_cnt_drop[STATUS_CNT_DROP_WIDTH-1:0];
    status[LSB_STATUS_RX_LVL +: STATUS_RX_LVL_WIDTH] = shadow_rx_fifo_level[STATUS_RX_LVL_WIDTH-1:0];
    status[LSB_STATUS_TX_LVL +: STATUS_TX_LVL_WIDTH] = shadow_tx_fifo_level[STATUS_TX_LVL_WIDTH-1:0];
    return status;
  endfunction

// Revisar valor de salida de los IRQ's
  protected function bit compute_expected_irq_pin();
    bit expected_irq = 0;
    
    expected_irq |= (shadow_irq_rx_fifo_empty & shadow_irqen_rx_fifo_empty);
    expected_irq |= (shadow_irq_rx_fifo_full  & shadow_irqen_rx_fifo_full);
    expected_irq |= (shadow_irq_tx_fifo_empty & shadow_irqen_tx_fifo_empty);
    expected_irq |= (shadow_irq_tx_fifo_full  & shadow_irqen_tx_fifo_full);
    expected_irq |= (shadow_irq_max_drop      & shadow_irqen_max_drop);
    
    return expected_irq;
  endfunction

  //--- Modelo de Referencia (Golden Model) ---//

  protected virtual function void predict_dut_output(md_packet input_pkt);
    // -- Declaración de variables locales --
    byte    current_byte;
    int     byte_index;
    
    // 1. Desensambla el paquete de entrada en bytes individuales y los añade a nuestro búfer.
    for (int i = 0; i < input_pkt.size; i++) begin
      byte_index = input_pkt.offset + i;
      current_byte = input_pkt.data[(byte_index*8) +: 8];
      m_byte_buffer_q.push_back(current_byte);
    end
    
    // 2. Comprueba si tenemos suficientes bytes en el búfer para crear uno o más paquetes de salida.
    while (m_byte_buffer_q.size() >= shadow_ctrl_size) begin
      // -- Declaración de variables para el bucle --
      md_packet predicted_pkt = new();
      bit [ALGN_DATA_WIDTH-1:0] output_data = 0;
      byte byte_to_place;
      int byte_index_in_output;
      
      $display("[%s] Modelo: ¡Suficientes bytes (%0d) para crear un paquete de salida (requerido: %0d)!",
               name, m_byte_buffer_q.size(), shadow_ctrl_size);

      // 3. Construye el paquete de salida esperado (Golden Packet)
      predicted_pkt.size   = shadow_ctrl_size;
      predicted_pkt.offset = shadow_ctrl_offset;

      for (int i = 0; i < shadow_ctrl_size; i++) begin
        // Saca el byte más antiguo del búfer
        byte_to_place = m_byte_buffer_q.pop_front();
        // Lo coloca en la posición correcta en la palabra de datos de salida
        byte_index_in_output = shadow_ctrl_offset + i;
        output_data[(byte_index_in_output*8) +: 8] = byte_to_place;
      end
      
      predicted_pkt.data = output_data;
      
      // 4. Añade el paquete de salida esperado a la cola de expectativas.
      m_expected_q.push_back(predicted_pkt);

      // Actualizar shadow TX FIFO level
      if (shadow_tx_fifo_level < FIFO_DEPTH) begin
        shadow_tx_fifo_level++;
      end
      // --- NUEVO: informamos al environment que hemos incrementado el número de outputs esperados.
//      if (m_env != null) m_env.add_expected_outputs(1);
      
      $display("[%s] Modelo: Paquete de salida PREDICHO y encolado. Data: %h, Size: %d, Offset: %d.",
               name, predicted_pkt.data, predicted_pkt.size, predicted_pkt.offset);
    end
  endfunction
  
  //--- Reporte Final ---//
  function void report();
    m_logger.close();
    $display("-------------------------------------------------");
    $display("[%s] Reporte Final de Simulación", name);
    $display("-------------------------------------------------");
    $display("  Paquetes Coincidentes (MATCH):   %0d", match_count);
    $display("  Paquetes no Coincidentes (MISMATCH): %0d", mismatch_count);
    if (m_expected_q.size() > 0) begin
      $warning("[%s] %0d paquetes se esperaban pero nunca fueron emitidos por el DUT.", name, m_expected_q.size());
    end
    $display("-------------------------------------------------");
  endfunction

endclass



