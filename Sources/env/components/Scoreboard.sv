class scoreboard;
  import dut_params_pkg::*;

  string name = "Scoreboard";

  //--- Mailboxes para recibir datos de TODOS los monitores ---//
  mailbox #(md_packet)        rx_mon_mbx; // Paquetes de entrada capturados
  mailbox #(md_packet)        tx_mon_mbx; // Paquetes de salida capturados
  mailbox #(apb_transaction)  apb_mon_mbx; // Transacciones APB capturadas

  //--- Componentes de utilidad que el scoreboard utiliza ---//
  protected checker    m_checker;
  protected csv_logger m_logger;
  
  //--- Colas internas y Modelo del DUT ---//
  protected md_packet  m_expected_q[$]; // Cola de paquetes de salida esperados
  protected byte m_byte_buffer_q[$];

  // Shadow Registers para el modelo del bus de control APB
  protected bit [ALGN_SIZE_WIDTH-1:0]   shadow_ctrl_size = 1;
  protected bit [ALGN_OFFSET_WIDTH-1:0] shadow_ctrl_offset = 0;
  protected int unsigned                shadow_cnt_drop = 0;

  //--- Contadores para el reporte final ---//
  int unsigned match_count = 0;
  int unsigned mismatch_count = 0;
  
  //--- Constructor ---//
  function new(mailbox #(md_packet) rx_mon_mbx,
               mailbox #(md_packet) tx_mon_mbx,
               mailbox #(apb_transaction) apb_mon_mbx);
    // Asignación de mailboxes
    this.rx_mon_mbx = rx_mon_mbx;
    this.tx_mon_mbx = tx_mon_mbx;
    this.apb_mon_mbx = apb_mon_mbx;
    
    // Instancia de sus utilidades
    m_checker = new();
    // Podríamos pasar el nombre del archivo CSV desde el test a través del constructor
    m_logger = new("simulation_log.csv"); 
  endfunction

  //--- Tarea Principal ---//
  task run();
    $display("[%s] El scoreboard ha comenzado.", name);
    fork
      // Proceso 1: Observar bus de entrada y predecir salidas
      process_inputs_and_predict();
      
      // Proceso 2: Observar bus de salida y coordinar la comparación
      process_outputs_and_check();
      
      // Proceso 3: Observar bus APB y actualizar el modelo interno
      process_apb_config();
    join
  endtask
  
  //--- Tareas de Proceso ---//

  // 1. Espera paquetes de entrada, actualiza contadores y los pasa al modelo predictivo.
  protected task process_inputs_and_predict();
    forever begin
      md_packet rx_pkt;
      rx_mon_mbx.get(rx_pkt);
      
      // Si el paquete es ilegal según el monitor, actualizamos nuestro contador de drops
      // Asumimos que el monitor RX determina la legalidad y la pone en el paquete que envía
      if (!rx_pkt.is_legal) begin
        shadow_cnt_drop++;
      end else 
        // Si es legal, llamamos al modelo para generar una expectativa de salida
        predict_dut_output(rx_pkt);
      end
  endtask

  // 2. Espera paquetes de salida, los envía al Checker para comparar y luego loguea.
  protected task process_outputs_and_check();
    forever begin
      md_packet actual_pkt, expected_pkt;
      bit match;
      
      // Obtiene el paquete de salida real capturado por el monitor TX
      tx_mon_mbx.get(actual_pkt);
      
      if (m_expected_q.size() == 0) begin
        $error("[%s] ¡Paquete de salida inesperado recibido del DUT! Data: %h", name, actual_pkt.data);
        mismatch_count++;
        continue;
      end
      
      // Obtiene el siguiente paquete esperado de nuestra cola de predicciones
      expected_pkt = m_expected_q.pop_front();
      
      // *** ARQUITECTURA CLAVE: Envía el par al Checker y espera el resultado ***
      match = m_checker.compare(expected_pkt, actual_pkt);
      
      if (match) begin
        $display("[%s] *** PACKET MATCH (verificado por Checker) ***", name);
        match_count++;
      end else begin
        mismatch_count++;
        // El checker ya imprimió los detalles del error
      end
      
      // Usa el resultado para escribir en el log CSV
      m_logger.log_entry(match, actual_pkt, expected_pkt);
    end
  endtask
  
  // 3. Espera transacciones APB y actualiza el estado del modelo interno.
  protected task process_apb_config();
    forever begin
      apb_transaction tx;
      bit [31:0] predicted_rdata;
      apb_mon_mbx.get(tx);
      
      case (tx.addr)
        `ADDR_CTRL: begin
          if (tx.op == APB_WRITE) begin
            $display("[%s] Escritura en ADDR_CTRL detectada. Actualizando modelo interno.", name);
            // Actualiza los shadow registers. El modelo predictivo los usará.
            this.shadow_ctrl_size = tx.wdata[LSB_CTRL_SIZE +: ALGN_SIZE_WIDTH];
            this.shadow_ctrl_offset = tx.wdata[LSB_CTRL_OFFSET +: ALGN_OFFSET_WIDTH];
            // Si el bit 'clr' está activo
            if(tx.wdata[LSB_CTRL_CLR]) this.shadow_cnt_drop = 0;
          end
        end
        `ADDR_STATUS: begin
          if (tx.op == APB_READ) begin
            predicted_rdata = 0;
            predicted_rdata[LSB_STATUS_CNT_DROP +: STATUS_CNT_DROP_WIDTH] = shadow_cnt_drop;
            // ... Aquí también predeciríamos el nivel de las FIFOs si lo modeláramos ...
            
            if (predicted_rdata !== tx.rdata) begin
              $error("[%s] MISMATCH en lectura de ADDR_STATUS. Esperado: %h, Recibido: %h", name, predicted_rdata, tx.rdata);
            end
          end
        end
        // ... Lógica para otros registros como IRQEN, IRQ ...
      endcase
    end
  endtask

  //--- Modelo de Referencia ---//
  protected virtual function void predict_dut_output(md_packet input_pkt);
    // *** CORRECCIÓN FINAL AQUÍ ***
    // Se declaran TODAS las variables locales al principio de la función.
    md_packet predicted_pkt;
    bit [ALGN_DATA_WIDTH-1:0] output_data;
    int byte_index;
    byte current_byte;
    int byte_index_in_output;
    byte byte_to_place;

    $display("[%s] Modelo: Recibido paquete de entrada. Size: %d, Offset: %d.", name, input_pkt.size, input_pkt.offset);
    for (int i = 0; i < input_pkt.size; i++) begin
      byte_index = input_pkt.offset + i;
      current_byte = input_pkt.data[(byte_index*8) +: 8];
      m_byte_buffer_q.push_back(current_byte);
    end
    $display("[%s] Modelo: Búfer interno ahora tiene %0d bytes.", name, m_byte_buffer_q.size());

    while (m_byte_buffer_q.size() >= shadow_ctrl_size) begin
      $display("[%s] Modelo: ¡Suficientes bytes (%0d) para crear un paquete de salida (tamaño requerido: %0d)!",
               name, m_byte_buffer_q.size(), shadow_ctrl_size);
      
      // Se asigna el valor, no se declara la variable.
      predicted_pkt = new();
      output_data = 0;

      predicted_pkt.size   = shadow_ctrl_size;
      predicted_pkt.offset = shadow_ctrl_offset;
      for (int i = 0; i < shadow_ctrl_size; i++) begin
        byte_index_in_output = shadow_ctrl_offset + i;
        byte_to_place = m_byte_buffer_q.pop_front();
        output_data[(byte_index_in_output*8) +: 8] = byte_to_place;
      end
      predicted_pkt.data = output_data;
      m_expected_q.push_back(predicted_pkt);
      $display("[%s] Modelo: Paquete de salida predicho y encolado. Data: %h, Size: %d, Offset: %d.",
               name, predicted_pkt.data, predicted_pkt.size, predicted_pkt.offset);
      $display("[%s] Modelo: Quedan %0d bytes en el búfer interno.", name, m_byte_buffer_q.size());
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
      $error("[%s] %0d paquetes se esperaban pero nunca fueron emitidos por el DUT.", name, m_expected_q.size());
    end
    $display("-------------------------------------------------");
  endfunction

endclass