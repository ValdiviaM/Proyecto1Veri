'include "pkt5.sv"
'include "pkt6.sv"

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
    mailbox #(pkt6) gen2scb,
    mailbox #(pkt5) scb2chk,
    string test_name = "aligner_test"
  );
    this.gen2scb_mbx = gen2scb;
    this.mon2scb_mbx = mon2scb;
    this.scb2chk_mbx = scb2chk;
    this.test_name = test_name;
    
    this.enable = 1;

    
          
    // Crear reporter CSV
    this.reporter = new(test_name, "./csv_results");
    
    $display("[SCOREBOARD] Created for test: %s", test_name);
  endfunction
  

  // Task Principal - Run  
  task run();
    
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
  
  // Recibir Tests Esperados del Generator  
  task receive_expected_tests();
    pkt1 test;
    
    forever begin
      gen2scb_mbx.get(test);
      
      total_tests_expected++;
      expected_tests.push_back(test.copy());

      // Actualizar modelo de referencia si es necesario
      update_reference_from_test(test);
    end
  endtask
  
  // Recibir Observaciones de los Monitors  
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
  
  // Actualizar Modelo de Referencia desde Test  
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
  
  // Actualizar Modelo de Referencia desde Observación
  
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
  
  
  // Calcular Métricas de Performance  
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
  

endclass