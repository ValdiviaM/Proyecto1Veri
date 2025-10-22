class environment;
  string name = "Environment";
  
  generator    m_gen;
  md_driver    m_md_driver;
  apb_driver   m_apb_driver;
  md_monitor   m_md_rx_monitor;
  md_monitor   m_md_tx_monitor;
  apb_monitor  m_apb_monitor;
  scoreboard   m_scoreboard;
  
  event all_packets_processed;
  protected int unsigned total_packets_expected = 0;
  protected int unsigned packets_processed_count = 0;

  virtual md_interface  m_md_rx_vif;
  virtual md_interface  m_md_tx_vif;
  virtual apb_interface m_apb_vif;
  
  protected mailbox #(md_packet)        md_gen2drv_mbx;
  protected mailbox #(apb_transaction)  apb_gen2drv_mbx;
  protected mailbox #(md_packet)        md_rx_mon2scb_mbx;
  protected mailbox #(md_packet)        md_tx_mon2scb_mbx;
  protected mailbox #(apb_transaction)  apb_mon2scb_mbx;
  
  function new(virtual md_interface md_rx_vif,
               virtual md_interface md_tx_vif,
               virtual apb_interface apb_vif);
    $display("[%s] Creando el entorno...", name);
    this.m_md_rx_vif = md_rx_vif;
    this.m_md_tx_vif = md_tx_vif;
    this.m_apb_vif = apb_vif;
  endfunction
  
  task build_phase();
    $display("[%s] Fase de Construcción (Build)...", name);
    
    md_gen2drv_mbx    = new();
    apb_gen2drv_mbx   = new();
    md_rx_mon2scb_mbx = new();
    md_tx_mon2scb_mbx = new();
    apb_mon2scb_mbx   = new();
    
    m_gen = new(md_gen2drv_mbx, apb_gen2drv_mbx, this);
    
    // Conectamos el driver al modport 'Driver'
    m_md_driver = new(m_md_rx_vif, md_gen2drv_mbx);
    m_apb_driver = new(m_apb_vif.Driver, apb_gen2drv_mbx); // Usando el modport .Driver
    
    // Conectamos los monitores al modport 'Monitor'
    m_md_rx_monitor = new("MD_RX_Monitor", m_md_rx_vif, md_rx_mon2scb_mbx);
    m_md_tx_monitor = new("MD_TX_Monitor", m_md_tx_vif, md_tx_mon2scb_mbx);
    m_apb_monitor = new(m_apb_vif.Monitor, apb_mon2scb_mbx); // Usando el modport .Monitor
    
    m_scoreboard = new(md_rx_mon2scb_mbx, md_tx_mon2scb_mbx, apb_mon2scb_mbx, this);

    $display("[%s] Todos los componentes del entorno han sido construidos.", name);
  endtask
  
  task run_phase();
    $display("[%s] Fase de Ejecución (Run)... Lanzando todos los procesos.", name);
    fork
      m_gen.run();
      m_md_driver.run();
      m_apb_driver.run();
      m_md_rx_monitor.run();
      m_md_tx_monitor.run();
      m_apb_monitor.run();
      m_scoreboard.run();
    join_none
  endtask

  function void report_generation_done(int unsigned total_count);
    $display("[%s] El generador reporta que ha terminado. Total de paquetes generados: %0d", name, total_count);
    this.total_packets_expected = total_count;
    this.check_completion(); // Es necesario por si se generaron 0 paquetes.
  endfunction
  
  // El scoreboard llama a esta función por cada paquete procesado.
  function void report_packet_processed();
    this.packets_processed_count++;
    $display("[%s] Progreso: %0d de %0d paquetes procesados.", name, packets_processed_count, total_packets_expected);
    this.check_completion();
  endfunction

  protected function void check_completion();
    // Solo disparamos el evento si la generación ya terminó (total > 0)
    // y si ya hemos procesado todos los paquetes esperados.
    if (total_packets_expected > 0 && (packets_processed_count >= total_packets_expected)) begin
      $display("[%s] ¡Condición de finalización alcanzada! Todos los paquetes han sido procesados.", name);
      -> all_packets_processed; // Dispara el evento
    end
  endfunction

  task report_phase();
    m_scoreboard.report();
  endtask

endclass
