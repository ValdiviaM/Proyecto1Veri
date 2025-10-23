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
    this.m_env = m_env; // handle del environment
    
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
  protected task process_inputs_and_predict();
    forever begin
      md_packet rx_pkt;
      bit is_pkt_legal;

      rx_mon_mbx.get(rx_pkt);
      
      // Replica la lógica del DUT para determinar legalidad
      if (rx_pkt.size == 0 || ((((ALGN_DATA_WIDTH / 8) + rx_pkt.offset) % rx_pkt.size) != 0)) begin
        is_pkt_legal = 0;
      end else begin
        is_pkt_legal = 1;
      end

      if (!is_pkt_legal) begin
        shadow_cnt_drop++;
        if (shadow_cnt_drop >= MAX_DROP_COUNT) begin
          shadow_cnt_drop_maxed = 1;
          shadow_irq_max_drop = 1;
        end
        $display("[%s] Modelo: Paquete ILEGAL descartado (size=%0d, offset=%0d)", name, rx_pkt.size, rx_pkt.offset);
      end else begin
        legal_packets_received++;

        // Update RX FIFO
        if (shadow_rx_fifo_level < FIFO_DEPTH) begin
          shadow_rx_fifo_level++;
        end
        if (shadow_rx_fifo_level == FIFO_DEPTH)
          shadow_irq_rx_fifo_full = 1;
        if (shadow_rx_fifo_level == 0)
          shadow_irq_rx_fifo_empty = 1;

        $display("[%s] Modelo: Paquete LEGAL aceptado. RX FIFO level=%0d", name, shadow_rx_fifo_level);
        predict_dut_output(rx_pkt);

        // Simula consumo del FIFO
        if (shadow_rx_fifo_level > 0) begin
          shadow_rx_fifo_level--;
        end
        if (shadow_rx_fifo_level == 0)
          shadow_irq_rx_fifo_empty = 1;
        else
          shadow_irq_rx_fifo_empty = 0;
      end

      // Actualiza IRQ pin esperado
      m_env.set_irq_pin(compute_expected_irq_pin());
    end
  endtask

  protected task process_outputs_and_check();
    forever begin
      md_packet actual_pkt, expected_pkt;
      bit match;
      
      tx_mon_mbx.get(actual_pkt);
      
      if (m_expected_q.size() == 0) begin
        $error("[%s] ¡Salida inesperada del DUT! Cola vacía.", name);
        mismatch_count++;
        expected_pkt = new();
        m_logger.log_entry(0, actual_pkt, expected_pkt);
        m_env.report_output_processed();
        continue;
      end
      
      expected_pkt = m_expected_q.pop_front();
      match = m_checker.compare(expected_pkt, actual_pkt);
      
      if (match) begin
        match_count++;
        $display("[%s] *** PACKET MATCH ***", name);
      end else begin
        mismatch_count++;
      end
      
      // TX FIFO consume un elemento
      if (shadow_tx_fifo_level > 0)
        shadow_tx_fifo_level--;
      if (shadow_tx_fifo_level == 0)
        shadow_irq_tx_fifo_empty = 1;
      else
        shadow_irq_tx_fifo_empty = 0;

      m_logger.log_entry(match, actual_pkt, expected_pkt);
      m_env.report_output_processed();

      // Actualiza IRQ pin esperado
      m_env.set_irq_pin(compute_expected_irq_pin());
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
              if (!tx.error)
                $error("[%s] APB: Expected ERROR on CTRL write not seen!", name);
            end else begin
              shadow_ctrl_size = tx.wdata[LSB_CTRL_SIZE +: ALGN_SIZE_WIDTH];
              shadow_ctrl_offset = tx.wdata[LSB_CTRL_OFFSET +: ALGN_OFFSET_WIDTH];
              
              if (tx.wdata[LSB_CTRL_CLR]) begin
                shadow_cnt_drop = 0;
                shadow_cnt_drop_maxed = 0;
                shadow_irq_max_drop = 0;
                $display("[%s] APB: CTRL.CLR - drop counter reset", name);
              end
            end
          end
        end
        
        `ADDR_STATUS: begin
          if (tx.op == APB_WRITE) begin
            apb_writes_processed++;
            apb_errors_expected++;
          end else begin
            apb_reads_processed++;
            expected_rdata = build_expected_status();
            if (tx.rdata !== expected_rdata)
              $warning("[%s] STATUS mismatch! Exp=%h Got=%h", name, expected_rdata, tx.rdata);
          end
        end
        
        `ADDR_IRQEN: begin
          if (tx.op == APB_WRITE) begin
            apb_writes_processed++;
            shadow_irqen_rx_fifo_empty = tx.wdata[LSB_IRQEN_RX_FIFO_EMPTY];
            shadow_irqen_rx_fifo_full  = tx.wdata[LSB_IRQEN_RX_FIFO_FULL];
            shadow_irqen_tx_fifo_empty = tx.wdata[LSB_IRQEN_TX_FIFO_EMPTY];
            shadow_irqen_tx_fifo_full  = tx.wdata[LSB_IRQEN_TX_FIFO_FULL];
            shadow_irqen_max_drop      = tx.wdata[LSB_IRQEN_MAX_DROP];
            $display("[%s] APB: IRQEN updated", name);
          end else begin
            apb_reads_processed++;
          end
          m_env.set_irq_pin(compute_expected_irq_pin()); // <--- IRQ puede cambiar
        end
        
        `ADDR_IRQ: begin
          if (tx.op == APB_WRITE) begin
            apb_writes_processed++;
            if (tx.wdata[LSB_IRQ_RX_FIFO_EMPTY]) shadow_irq_rx_fifo_empty = 0;
            if (tx.wdata[LSB_IRQ_RX_FIFO_FULL])  shadow_irq_rx_fifo_full  = 0;
            if (tx.wdata[LSB_IRQ_TX_FIFO_EMPTY]) shadow_irq_tx_fifo_empty = 0;
            if (tx.wdata[LSB_IRQ_TX_FIFO_FULL])  shadow_irq_tx_fifo_full  = 0;
            if (tx.wdata[LSB_IRQ_MAX_DROP])      shadow_irq_max_drop      = 0;
          end else begin
            apb_reads_processed++;
          end
          m_env.set_irq_pin(compute_expected_irq_pin()); // <--- IRQ puede cambiar
        end
        
        default: begin
          apb_errors_expected++;
        end
      endcase
    end
  endtask

  // Check CTRL write legality
  protected function bit check_ctrl_write_validity(bit [31:0] wdata);
    bit [ALGN_SIZE_WIDTH-1:0] new_size;
    bit [ALGN_OFFSET_WIDTH-1:0] new_offset;
    new_size = wdata[LSB_CTRL_SIZE +: ALGN_SIZE_WIDTH];
    new_offset = wdata[LSB_CTRL_OFFSET +: ALGN_OFFSET_WIDTH];
    if (new_size == 0) return 1;
    if ((((ALGN_DATA_WIDTH / 8) + new_offset) % new_size) != 0) return 1;
    return 0;
  endfunction

  protected function bit [31:0] build_expected_status();
    bit [31:0] status = 0;
    status[LSB_STATUS_CNT_DROP +: STATUS_CNT_DROP_WIDTH] = shadow_cnt_drop[STATUS_CNT_DROP_WIDTH-1:0];
    status[LSB_STATUS_RX_LVL +: STATUS_RX_LVL_WIDTH] = shadow_rx_fifo_level[STATUS_RX_LVL_WIDTH-1:0];
    status[LSB_STATUS_TX_LVL +: STATUS_TX_LVL_WIDTH] = shadow_tx_fifo_level[STATUS_TX_LVL_WIDTH-1:0];
    return status;
  endfunction

  // Calcular estado global del pin IRQ
  protected function bit compute_expected_irq_pin();
    bit expected_irq = 0;
    expected_irq |= (shadow_irq_rx_fifo_empty & shadow_irqen_rx_fifo_empty);
    expected_irq |= (shadow_irq_rx_fifo_full  & shadow_irqen_rx_fifo_full);
    expected_irq |= (shadow_irq_tx_fifo_empty & shadow_irqen_tx_fifo_empty);
    expected_irq |= (shadow_irq_tx_fifo_full  & shadow_irqen_tx_fifo_full);
    expected_irq |= (shadow_irq_max_drop      & shadow_irqen_max_drop);
    return expected_irq;
  endfunction

  //--- Modelo de referencia ---//
  protected virtual function void predict_dut_output(md_packet input_pkt);
    byte current_byte;
    int byte_index;

    for (int i = 0; i < input_pkt.size; i++) begin
      byte_index = input_pkt.offset + i;
      current_byte = input_pkt.data[(byte_index*8) +: 8];
      m_byte_buffer_q.push_back(current_byte);
    end
    
    while (m_byte_buffer_q.size() >= shadow_ctrl_size) begin
      md_packet predicted_pkt = new();
      bit [ALGN_DATA_WIDTH-1:0] output_data = 0;
      byte byte_to_place;
      int byte_index_in_output;
      
      predicted_pkt.size   = shadow_ctrl_size;
      predicted_pkt.offset = shadow_ctrl_offset;

      for (int i = 0; i < shadow_ctrl_size; i++) begin
        byte_to_place = m_byte_buffer_q.pop_front();
        byte_index_in_output = shadow_ctrl_offset + i;
        output_data[(byte_index_in_output*8) +: 8] = byte_to_place;
      end
      predicted_pkt.data = output_data;
      m_expected_q.push_back(predicted_pkt);

      if (shadow_tx_fifo_level < FIFO_DEPTH)
        shadow_tx_fifo_level++;
      if (shadow_tx_fifo_level == FIFO_DEPTH)
        shadow_irq_tx_fifo_full = 1;
      else
        shadow_irq_tx_fifo_full = 0;

      $display("[%s] Modelo: Paquete predicho y encolado. TX FIFO=%0d", name, shadow_tx_fifo_level);
      m_env.set_irq_pin(compute_expected_irq_pin()); // IRQ puede cambiar por TX lleno
    end
  endfunction
  
  //--- Reporte Final ---//
  function void report();
    m_logger.close();
    $display("-------------------------------------------------");
    $display("[%s] Reporte Final", name);
    $display("  MATCH: %0d", match_count);
    $display("  MISMATCH: %0d", mismatch_count);
    if (m_expected_q.size() > 0)
      $warning("[%s] %0d paquetes esperados nunca emitidos.", name, m_expected_q.size());
    $display("-------------------------------------------------");
  endfunction

endclass

