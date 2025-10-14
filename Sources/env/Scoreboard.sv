
class Scoreboard;
  

  
  mailbox #(pkt6) gen2scb_mbx;    // Recibe tests esperados del Generator
  mailbox #(pkt5) scb2chk_mbx;    // Envía verificaciones al Checker
  

  // Colas de Almacenamiento
  
  pkt1 expected_tests[$];         // Tests esperados
  pkt3 observed_apb[$];           // Observaciones APB
  pkt3 observed_md_rx[$];         // Observaciones MD RX
  pkt3 observed_md_tx[$];         // Observaciones MD TX
  pkt3 observed_irq[$];           // Observaciones IRQ
  pkt3 all_observations[$];       // Todas las observaciones
  
  
  // Modelo de Referencia del DUT
  
  // Estado de registros
  bit [2:0]  ref_ctrl_size;
  bit [1:0]  ref_ctrl_offset;
  bit [7:0]  ref_status_cnt_drop;
  bit [3:0]  ref_status_rx_lvl;
  bit [3:0]  ref_status_tx_lvl;
  bit [4:0]  ref_irqen;
  bit [4:0]  ref_irq_flags;
  bit        ref_irq_out;
  
  // FIFOs del modelo de referencia
  bit [31:0] ref_rx_fifo[$];
  bit [31:0] ref_tx_fifo[$];
  int        FIFO_DEPTH = 8;
  
  // Estado de alineamiento
  bit [31:0] ref_alignment_buffer;
  int        ref_buffer_bytes;
  
  // Estadísticas  
  int total_tests_expected;
  int total_tests_completed;
  int total_apb_writes;
  int total_apb_reads;
  int total_md_rx_trans;
  int total_md_tx_trans;
  int total_irq_events;
  int total_illegal_trans;
  int total_errors;
  int total_warnings;
  int total_matches;
  int total_mismatches;
  
  // Performance metrics
  real min_alignment_latency;
  real max_alignment_latency;
  real total_alignment_latency;
  int  alignment_count;
  
  // Control
  bit enable;
  string test_name;
  
  // Constructor  
  function new(
    mailbox #(pkt1) gen2scb,
    mailbox #(pkt5) scb2chk,
    string test_name = "aligner_test"
  );
    this.gen2scb_mbx = gen2scb;
    this.mon2scb_mbx = mon2scb;
    this.scb2chk_mbx = scb2chk;
    this.test_name = test_name;
    
    this.enable = 1;

    
    // Inicializar modelo de referencia
    reset_reference_model();
    
    // Inicializar estadísticas
    reset_statistics();
    
    // Crear reporter CSV
    this.reporter = new(test_name, "./csv_results");
    
    $display("[SCOREBOARD] Created for test: %s", test_name);
  endfunction
  
  // ========================================================================
  // Reset del Modelo de Referencia
  // ========================================================================
  
  function void reset_reference_model();
    ref_ctrl_size = 1;
    ref_ctrl_offset = 0;
    ref_status_cnt_drop = 0;
    ref_status_rx_lvl = 0;
    ref_status_tx_lvl = 0;
    ref_irqen = 0;
    ref_irq_flags = 0;
    ref_irq_out = 0;
    
    ref_rx_fifo.delete();
    ref_tx_fifo.delete();
    
    ref_alignment_buffer = 0;
    ref_buffer_bytes = 0;
    
    if (verbose)
      $display("[SCOREBOARD] Reference model reset");
  endfunction
  
  function void reset_statistics();
    total_tests_expected = 0;
    total_tests_completed = 0;
    total_apb_writes = 0;
    total_apb_reads = 0;
    total_md_rx_trans = 0;
    total_md_tx_trans = 0;
    total_irq_events = 0;
    total_illegal_trans = 0;
    total_errors = 0;
    total_warnings = 0;
    total_matches = 0;
    total_mismatches = 0;
    
    min_alignment_latency = 1e9;
    max_alignment_latency = 0;
    total_alignment_latency = 0;
    alignment_count = 0;
  endfunction
  
  // ========================================================================
  // Task Principal - Run
  // ========================================================================
  
  task run();
    if (verbose)
      $display("[SCOREBOARD] Started at %0t", $time);
    
    // Abrir archivos CSV
    if (!reporter.open_files()) begin
      $error("[SCOREBOARD] Failed to open CSV files");
      return;
    end
    
    fork
      // Thread para recibir tests esperados
      receive_expected_tests();
      
      // Thread para recibir observaciones
      receive_observations();
      
      // Thread para procesar y verificar
      process_and_verify();
      
    join_none
  endtask
  
  // ========================================================================
  // Recibir Tests Esperados del Generator
  // ========================================================================
  
  task receive_expected_tests();
    pkt1 test;
    
    forever begin
      gen2scb_mbx.get(test);
      
      total_tests_expected++;
      expected_tests.push_back(test.copy());
      
      if (verbose) begin
        $display("[SCOREBOARD] Received expected test #%0d at %0t",
                 test.transaction_id, $time);
        test.display("  ");
      end
      
      // Actualizar modelo de referencia si es necesario
      update_reference_from_test(test);
    end
  endtask
  
  // ========================================================================
  // Recibir Observaciones de los Monitors
  // ========================================================================
  
  task receive_observations();
    pkt3 obs;
    
    forever begin
      mon2scb_mbx.get(obs);
      
      // Clasificar observación
      case (obs.obs_type)
        pkt3::OBS_APB: begin
          observed_apb.push_back(obs.copy());
          if (obs.apb_write) total_apb_writes++;
          else total_apb_reads++;
          
          // Log en CSV
          reporter.log_apb_transaction(obs);
        end
        
        pkt3::OBS_MD_RX: begin
          observed_md_rx.push_back(obs.copy());
          total_md_rx_trans++;
          
          if (!obs.is_md_legal()) total_illegal_trans++;
          
          // Log en CSV
          reporter.log_md_transaction(obs);
        end
        
        pkt3::OBS_MD_TX: begin
          observed_md_tx.push_back(obs.copy());
          total_md_tx_trans++;
          
          // Log en CSV
          reporter.log_md_transaction(obs);
        end
        
        pkt3::OBS_IRQ: begin
          observed_irq.push_back(obs.copy());
          total_irq_events++;
        end
      endcase
      
      // Guardar en lista completa
      all_observations.push_back(obs.copy());
      
      if (verbose) begin
        $display("[SCOREBOARD] Received observation at %0t", $time);
        obs.display("  ");
      end
      
      // Actualizar modelo de referencia
      update_reference_from_observation(obs);
      
      // Si auto_check está habilitado, verificar inmediatamente
      if (auto_check) begin
        check_observation(obs);
      end
    end
  endtask
  
  // ========================================================================
  // Actualizar Modelo de Referencia desde Test
  // ========================================================================
  
  function void update_reference_from_test(pkt1 test);
    case (test.test_type)
      pkt1::TEST_RESET: begin
        reset_reference_model();
      end
      
      pkt1::TEST_ALIGNMENT: begin
        // El test espera cierta configuración de alineamiento
        // No actualizamos aquí, esperamos el APB write correspondiente
      end
      
      pkt1::TEST_INTERRUPT: begin
        // Esperamos ciertas interrupciones
      end
      
      default: begin
        // Otros casos
      end
    endcase
  endfunction
  
  // ========================================================================
  // Actualizar Modelo de Referencia desde Observación
  // ========================================================================
  
  function void update_reference_from_observation(pkt3 obs);
    case (obs.obs_type)
      pkt3::OBS_APB: begin
        if (obs.is_apb_transfer_complete() && obs.apb_write) begin
          update_reference_registers(obs);
        end
      end
      
      pkt3::OBS_MD_RX: begin
        if (obs.is_md_transfer_complete()) begin
          process_md_rx_in_model(obs);
        end
      end
      
      pkt3::OBS_MD_TX: begin
        if (obs.is_md_transfer_complete()) begin
          process_md_tx_in_model(obs);
        end
      end
      
      pkt3::OBS_IRQ: begin
        ref_irq_out = obs.irq;
        ref_irq_flags = obs.irq_status;
      end
    endcase
  endfunction
  
  // ========================================================================
  // Actualizar Registros del Modelo de Referencia
  // ========================================================================
  
  function void update_reference_registers(pkt3 obs);
    bit [15:0] addr = obs.apb_addr & 16'hFFFC;
    
    case (addr)
      16'h0000: begin  // CTRL
        ref_ctrl_size = obs.apb_wdata[2:0];
        ref_ctrl_offset = obs.apb_wdata[9:8];
        
        // Si CLR bit está set
        if (obs.apb_wdata[16]) begin
          ref_status_cnt_drop = 0;
        end
        
        if (verbose)
          $display("[SCOREBOARD] Updated CTRL: SIZE=%0d OFFSET=%0d",
                   ref_ctrl_size, ref_ctrl_offset);
      end
      
      16'h00F0: begin  // IRQEN
        ref_irqen = obs.apb_wdata[4:0];
        
        if (verbose)
          $display("[SCOREBOARD] Updated IRQEN: 0x%02h", ref_irqen);
      end
      
      16'h00F4: begin  // IRQ (W1C)
        // Clear bits where 1 is written
        ref_irq_flags &= ~obs.apb_wdata[4:0];
        
        if (verbose)
          $display("[SCOREBOARD] Cleared IRQ flags: 0x%02h", obs.apb_wdata[4:0]);
      end
    endcase
    
    // Actualizar IRQ output
    ref_irq_out = |(ref_irq_flags & ref_irqen);
  endfunction
  
  // ========================================================================
  // Procesar MD RX en el Modelo
  // ========================================================================
  
  function void process_md_rx_in_model(pkt3 obs);
    // Verificar si es legal
    if (!obs.is_md_legal()) begin
      // Transferencia ilegal - incrementar contador
      if (ref_status_cnt_drop < 255) begin
        ref_status_cnt_drop++;
        
        if (ref_status_cnt_drop == 255) begin
          // Trigger IRQ_MAX_DROP
          ref_irq_flags[4] = 1;
          ref_irq_out = |(ref_irq_flags & ref_irqen);
        end
      end
      
      if (verbose)
        $display("[SCOREBOARD] Illegal MD RX, cnt_drop=%0d", ref_status_cnt_drop);
      
      return;
    end
    
    // Transferencia legal - agregar a FIFO RX
    if (ref_rx_fifo.size() < FIFO_DEPTH) begin
      ref_rx_fifo.push_back(obs.md_data);
      ref_status_rx_lvl = ref_rx_fifo.size();
      
      // Check FIFO full
      if (ref_rx_fifo.size() == FIFO_DEPTH) begin
        ref_irq_flags[1] = 1;  // RX_FIFO_FULL
        ref_irq_out = |(ref_irq_flags & ref_irqen);
      end
      
      if (verbose)
        $display("[SCOREBOARD] Added to RX FIFO, level=%0d", ref_status_rx_lvl);
    end else begin
      $warning("[SCOREBOARD] RX FIFO overflow in model!");
    end
  endfunction
  
  // ========================================================================
  // Procesar MD TX en el Modelo
  // ========================================================================
  
  function void process_md_tx_in_model(pkt3 obs);
    // Sacar dato del TX FIFO
    if (ref_tx_fifo.size() > 0) begin
      bit [31:0] expected_data = ref_tx_fifo.pop_front();
      ref_status_tx_lvl = ref_tx_fifo.size();
      
      // Check FIFO empty
      if (ref_tx_fifo.size() == 0) begin
        ref_irq_flags[2] = 1;  // TX_FIFO_EMPTY
        ref_irq_out = |(ref_irq_flags & ref_irqen);
      end
      
      // Verificar que el dato sea correcto
      if (obs.md_data !== expected_data) begin
        $error("[SCOREBOARD] TX data mismatch: expected=0x%08h, actual=0x%08h",
               expected_data, obs.md_data);
        total_errors++;
        reporter.log_error("ERROR", "DATA", "TX data mismatch", "Scoreboard",
                          $sformatf("0x%08h", expected_data),
                          $sformatf("0x%08h", obs.md_data));
      end
      
      if (verbose)
        $display("[SCOREBOARD] TX FIFO pop, level=%0d", ref_status_tx_lvl);
    end
  endfunction
  
  // ========================================================================
  // Procesar Alineamiento en el Modelo
  // ========================================================================
  
  function void process_alignment();
    // Tomar datos del RX FIFO y alinearlos al TX FIFO
    while (ref_rx_fifo.size() > 0 && ref_tx_fifo.size() < FIFO_DEPTH) begin
      bit [31:0] rx_data = ref_rx_fifo.pop_front();
      bit [31:0] tx_data;
      
      // Aquí implementarías la lógica de alineamiento según SIZE y OFFSET
      tx_data = align_data(rx_data, ref_ctrl_size, ref_ctrl_offset);
      
      ref_tx_fifo.push_back(tx_data);
      
      ref_status_rx_lvl = ref_rx_fifo.size();
      ref_status_tx_lvl = ref_tx_fifo.size();
      
      // Check RX FIFO empty
      if (ref_rx_fifo.size() == 0) begin
        ref_irq_flags[0] = 1;  // RX_FIFO_EMPTY
      end
      
      // Check TX FIFO full
      if (ref_tx_fifo.size() == FIFO_DEPTH) begin
        ref_irq_flags[3] = 1;  // TX_FIFO_FULL
      end
      
      ref_irq_out = |(ref_irq_flags & ref_irqen);
    end
  endfunction
  
  // ========================================================================
  // Función de Alineamiento (Modelo Golden)
  // ========================================================================
  
  function bit [31:0] align_data(
    bit [31:0] data,
    bit [2:0] size,
    bit [1:0] offset
  );
    bit [31:0] aligned_data;
    
    // Implementación simplificada del alineamiento
    // En un modelo real, esto debería replicar exactamente
    // el comportamiento del DUT
    
    case (size)
      1: begin  // 1 byte
        case (offset)
          0: aligned_data = {24'h0, data[7:0]};
          1: aligned_data = {16'h0, data[7:0], 8'h0};
          2: aligned_data = {8'h0, data[7:0], 16'h0};
          3: aligned_data = {data[7:0], 24'h0};
        endcase
      end
      
      2: begin  // 2 bytes
        case (offset)
          0: aligned_data = {16'h0, data[15:0]};
          2: aligned_data = {data[15:0], 16'h0};
          default: aligned_data = data;
        endcase
      end
      
      4: begin  // 4 bytes
        aligned_data = data;
      end
      
      default: aligned_data = data;
    endcase
    
    return aligned_data;
  endfunction
  
  // ========================================================================
  // Verificar Observación
  // ========================================================================
  
  function void check_observation(pkt3 obs);
    pkt5 check_pkt;
    
    case (obs.obs_type)
      pkt3::OBS_APB: begin
        check_pkt = create_check_packet_for_apb(obs);
      end
      
      pkt3::OBS_MD_TX: begin
        check_pkt = create_check_packet_for_tx(obs);
      end
      
      pkt3::OBS_IRQ: begin
        check_pkt = create_check_packet_for_irq(obs);
      end
      
      default: return;
    endcase
    
    // Enviar al checker si se creó un paquete
    if (check_pkt != null) begin
      scb2chk_mbx.put(check_pkt);
      
      if (verbose)
        check_pkt.display("[SCOREBOARD] Sent to checker: ");
    end
  endfunction
  
  // ========================================================================
  // Crear Paquetes de Verificación
  // ========================================================================
  
  function pkt5 create_check_packet_for_apb(pkt3 obs);
    pkt5 check_pkt = new();
    
    if (obs.apb_write) begin
      // Verificar que el write fue exitoso
      check_pkt.check_type = pkt5::CHK_REGISTER;
      check_pkt.set_expected_register_state(
        ref_ctrl_size, ref_ctrl_offset, ref_status_cnt_drop,
        ref_status_rx_lvl, ref_status_tx_lvl,
        ref_irqen, ref_irq_flags
      );
    end else begin
      // Verificar que el read retornó valores correctos
      check_pkt.check_type = pkt5::CHK_REGISTER;
      // Aquí compararíamos obs.apb_rdata con el modelo
    end
    
    return check_pkt;
  endfunction
  
  function pkt5 create_check_packet_for_tx(pkt3 obs);
    pkt5 check_pkt = new();
    
    check_pkt.check_type = pkt5::CHK_ALIGNMENT;
    
    // El dato TX debe estar alineado según la configuración
    bit [31:0] expected_data = align_data(
      ref_tx_fifo.size() > 0 ? ref_tx_fifo[0] : 0,
      ref_ctrl_size,
      ref_ctrl_offset
    );
    
    check_pkt.set_expected_alignment(
      expected_data,
      ref_ctrl_offset,
      ref_ctrl_size
    );
    
    // Verificar contra lo observado
    if (obs.md_data !== expected_data) begin
      total_mismatches++;
      reporter.log_error("ERROR", "ALIGNMENT", "TX data mismatch", "Scoreboard",
                        $sformatf("0x%08h", expected_data),
                        $sformatf("0x%08h", obs.md_data));
    end else begin
      total_matches++;
    end
    
    if (obs.md_offset !== ref_ctrl_offset) begin
      total_mismatches++;
      reporter.log_alignment_error(ref_ctrl_size, ref_ctrl_offset,
                                   obs.md_size, obs.md_offset);
    end else begin
      total_matches++;
    end
    
    return check_pkt;
  endfunction
  
  function pkt5 create_check_packet_for_irq(pkt3 obs);
    pkt5 check_pkt = new();
    
    check_pkt.check_type = pkt5::CHK_INTERRUPT;
    check_pkt.set_expected_irq(ref_irq_out, ref_irq_flags);
    
    // Verificar IRQ
    if (obs.irq !== ref_irq_out) begin
      total_mismatches++;
      reporter.log_irq_error(ref_irq_flags, obs.irq_status);
    end else begin
      total_matches++;
    end
    
    return check_pkt;
  endfunction
  
  // ========================================================================
  // Procesar y Verificar Continuamente
  // ========================================================================
  
  task process_and_verify();
    forever begin
      #10ns;  // Procesar cada 10ns
      
      if (enable) begin
        // Procesar alineamiento en el modelo
        process_alignment();
        
        // Verificar coherencia del modelo
        verify_model_coherence();
      end
    end
  endtask
  
  // ========================================================================
  // Verificar Coherencia del Modelo
  // ========================================================================
  
  function void verify_model_coherence();
    // Verificar que los niveles de FIFO sean consistentes
    if (ref_rx_fifo.size() != ref_status_rx_lvl) begin
      $warning("[SCOREBOARD] RX FIFO level mismatch in model: fifo=%0d, status=%0d",
               ref_rx_fifo.size(), ref_status_rx_lvl);
    end
    
    if (ref_tx_fifo.size() != ref_status_tx_lvl) begin
      $warning("[SCOREBOARD] TX FIFO level mismatch in model: fifo=%0d, status=%0d",
               ref_tx_fifo.size(), ref_status_tx_lvl);
    end
    
    // Verificar que IRQ out sea consistente con flags y enable
    bit expected_irq = |(ref_irq_flags & ref_irqen);
    if (ref_irq_out !== expected_irq) begin
      $warning("[SCOREBOARD] IRQ out inconsistent: actual=%b, expected=%b",
               ref_irq_out, expected_irq);
    end
  endfunction
  
  // ========================================================================
  // Calcular Métricas de Performance
  // ========================================================================
  
  function void calculate_performance_metrics();
    // Calcular latencia de alineamiento
    if (observed_md_rx.size() > 0 && observed_md_tx.size() > 0) begin
      foreach (observed_md_rx[i]) begin
        // Buscar TX correspondiente
        foreach (observed_md_tx[j]) begin
          if (observed_md_tx[j].timestamp > observed_md_rx[i].timestamp) begin
            real latency = (observed_md_tx[j].timestamp - observed_md_rx[i].timestamp) / 1ns;
            
            if (latency < min_alignment_latency) min_alignment_latency = latency;
            if (latency > max_alignment_latency) max_alignment_latency = latency;
            total_alignment_latency += latency;
            alignment_count++;
            
            break;
          end
        end
      end
    end
    
    // Reportar métricas
    if (alignment_count > 0) begin
      real avg_latency = total_alignment_latency / alignment_count;
      reporter.log_latency_stats(min_alignment_latency, max_alignment_latency, avg_latency);
    end
    
    // Calcular throughput
    real duration_ns = ($time - reporter.test_start_time) / 1ns;
    if (duration_ns > 0) begin
      int rx_bytes = total_md_rx_trans * 4;  // Asumiendo 4 bytes promedio
      int tx_bytes = total_md_tx_trans * 4;
      
      real rx_throughput_mbps = (rx_bytes * 8.0) / duration_ns * 1000.0;
      real tx_throughput_mbps = (tx_bytes * 8.0) / duration_ns * 1000.0;
      real efficiency = total_md_tx_trans > 0 ? 
                        100.0 * total_md_tx_trans / total_md_rx_trans : 0.0;
      
      reporter.log_throughput(rx_throughput_mbps, tx_throughput_mbps, efficiency);
    end
  endfunction
  
  // ========================================================================
  // Reporte Final
  // ========================================================================
  
  function void report();
    bit pass_fail;
    
    $display("========================================");
    $display("SCOREBOARD FINAL REPORT");
    $display("========================================");
    $display("Test: %s", test_name);
    $display("Duration: %0t", $time - reporter.test_start_time);
    $display("----------------------------------------");
    $display("Tests Expected:     %0d", total_tests_expected);
    $display("Tests Completed:    %0d", total_tests_completed);
    $display("APB Writes:         %0d", total_apb_writes);
    $display("APB Reads:          %0d", total_apb_reads);
    $display("MD RX Transfers:    %0d", total_md_rx_trans);
    $display("MD TX Transfers:    %0d", total_md_tx_trans);
    $display("IRQ Events:         %0d", total_irq_events);
    $display("Illegal Transfers:  %0d", total_illegal_trans);
    $display("----------------------------------------");
    $display("Matches:            %0d", total_matches);
    $display("Mismatches:         %0d", total_mismatches);
    $display("Errors:             %0d", total_errors);
    $display("Warnings:           %0d", total_warnings);
    $display("----------------------------------------");
    
    if (alignment_count > 0) begin
      $display("Alignment Latency:");
      $display("  Min: %.2f ns", min_alignment_latency);
      $display("  Max: %.2f ns", max_alignment_latency);
      $display("  Avg: %.2f ns", total_alignment_latency / alignment_count);
    end
    
    $display("========================================");
    
    pass_fail = (total_errors == 0 && total_mismatches == 0);
    
    if (pass_fail)
      $display("RESULT: PASS");
    else
      $display("RESULT: FAIL");
    
    $display("========================================");
    
    // Calcular y reportar métricas
    calculate_performance_metrics();
    
    // Generar reporte CSV final
    reporter.generate_final_report(
      expected_tests,
      all_observations,
      total_errors,
      total_warnings,
      pass_fail
    );
    
    // Cerrar archivos CSV
    reporter.close_files();
  endfunction
  
  // ========================================================================
  // Métodos de Control
  // ========================================================================
  
  function void set_verbose(bit v);
    verbose = v;
  endfunction
  
  function void set_strict_checking(bit s);
    strict_checking = s;
  endfunction
  
  function bit get_pass_fail();
    return (total_errors == 0 && total_mismatches == 0);
  endfunction
  
endclass : aligner_scoreboard