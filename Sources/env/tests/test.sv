class test;
  string name = "BaseTest";
  int unsigned num_md_packets = 100;
  int unsigned num_apb_ops    = 20;
  environment env;

  virtual task run(virtual md_interface md_rx_vif,
                   virtual md_interface md_tx_vif,
                   virtual apb_interface apb_vif);
    
    $display("[%s] Iniciando la configuración del test...", name);

    if ($value$plusargs("NUM_MD_PACKETS=%d", num_md_packets))
      $display("[%s] Plusarg detectado: Se generarán %0d paquetes MD.", name, num_md_packets);

    if ($value$plusargs("NUM_APB_OPS=%d", num_apb_ops))
      $display("[%s] Plusarg detectado: Se generarán %0d operaciones APB.", name, num_apb_ops);
    
    //--- Fase 2: Construcción del Entorno ---//
    env = new(md_rx_vif, md_tx_vif, apb_vif);
    env.add_expected_outputs(num_md_packets);
    env.build_phase();

    // Pasa los valores configurados a los componentes correspondientes (en este caso, al generador)
    env.m_gen.num_md_packets_to_generate = this.num_md_packets;
    env.m_gen.num_apb_ops_to_generate = this.num_apb_ops;

    $display("[%s] Entorno construido y configurado. Iniciando la simulación...", name);
    
    //--- Fase 4: Ejecución ---//
    // Lanza todos los procesos en segundo plano (drivers, monitores, scoreboard, generator)
    env.run_phase();
    $display("[%s] La ejecución del entorno ha sido lanzada en background.", name);

    // --- Ya no lanzamos env.m_gen.run() aquí (evitamos doble ejecución del generator).
    // El generator fue lanzado por env.run_phase() y correrá en paralelo.

    //--- Fase 5: Espera por completitud ---
    $display("[%s] Esperando a que todos los paquetes/outputs sean procesados por el scoreboard...", name);
    @(env.all_packets_processed);
    
    #100ns;

    $display("[%s] Simulación completada. Generando reporte...", name);
    env.report_phase();
    
    $finish();
  endtask

endclass

