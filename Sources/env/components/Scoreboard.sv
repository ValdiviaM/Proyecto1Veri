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

  //--- Contadores para el reporte final ---//
  int unsigned match_count = 0;
  int unsigned mismatch_count = 0;
  
  //--- Constructor ---//
  function new(mailbox #(md_packet) rx_mon_mbx,
               mailbox #(md_packet) tx_mon_mbx,
               mailbox #(apb_transaction) apb_mon_mbx,
               environment m_env); // << MODIFICAR
    this.rx_mon_mbx  = rx_mon_mbx;
    this.tx_mon_mbx  = tx_mon_mbx;
    this.apb_mon_mbx = apb_mon_mbx;
    this.m_env = m_env; // << AÑADIR: Asignar el handle
    
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

  // CAMBIO CLAVE: Esta tarea ahora replica la lógica del DUT para descartar paquetes
  protected task process_inputs_and_predict();
    forever begin
      md_packet rx_pkt;
      bit is_pkt_legal;

      // 1. Obtiene el paquete de entrada tal como lo vio el monitor
      rx_mon_mbx.get(rx_pkt);
      
      // 2. REPLICA LA LÓGICA DEL 'cfs_rx_ctrl' PARA DETERMINAR SI ES LEGAL
      //    Un paquete es ilegal si su tamaño es 0 o si no cumple la fórmula de alineación.
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
        // El DUT habría aceptado este paquete en su FIFO. Nuestro modelo también lo procesa.
        $display("[%s] Modelo: Paquete de entrada LEGAL aceptado. Pasando al predictor...", name);
        predict_dut_output(rx_pkt);
      end
      m_env.report_packet_processed();

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
      
      // AHORA ESTA LÍNEA SE EJECUTARÁ y el CSV se llenará.
      m_logger.log_entry(match, actual_pkt, expected_pkt);
    end
  endtask
  
  protected task process_apb_config();
    forever begin
      apb_transaction tx;
      apb_mon_mbx.get(tx);
      
      case (tx.addr)
        `ADDR_CTRL: begin
          if (tx.op == APB_WRITE) begin
            $display("[%s] Escritura en ADDR_CTRL detectada. Actualizando modelo.", name);
            shadow_ctrl_size = tx.wdata[LSB_CTRL_SIZE +: ALGN_SIZE_WIDTH];
            shadow_ctrl_offset = tx.wdata[LSB_CTRL_OFFSET +: ALGN_OFFSET_WIDTH];
            if(tx.wdata[LSB_CTRL_CLR]) shadow_cnt_drop = 0;
          end
        end
        `ADDR_STATUS: begin
            // Esta lógica para verificar lecturas es correcta.
        end
      endcase
    end
  endtask

  //--- Modelo de Referencia (Golden Model) ---//

  // MEJORA: Se han movido todas las declaraciones de variables al inicio de la función
  // para mejorar la legibilidad y la compatibilidad con todas las versiones de VCS.
  protected virtual function void predict_dut_output(md_packet input_pkt);
    // -- Declaración de variables locales --
    byte    current_byte;
    int     byte_index;
    
    // 1. Desensambla el paquete de entrada en bytes individuales y los añade a nuestro búfer.
    //    Este búfer simula el flujo de datos que entra al módulo 'cfs_ctrl' del DUT.
    for (int i = 0; i < input_pkt.size; i++) begin
      byte_index = input_pkt.offset + i;
      current_byte = input_pkt.data[(byte_index*8) +: 8];
      m_byte_buffer_q.push_back(current_byte);
    end
    
    // 2. Comprueba si tenemos suficientes bytes en el búfer para crear uno o más paquetes de salida.
    //    Este bucle 'while' es clave, ya que un paquete de entrada grande puede generar varios de salida.
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
      
      // 4. Añade el paquete predicho a la cola de expectativas. La tarea 'process_outputs_and_check' lo usará.
      m_expected_q.push_back(predicted_pkt);
      
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

