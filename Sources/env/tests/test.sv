class test;
  
  string name = "BaseTest";

  //--- Perillas de Configuración del Test (con valores por defecto) ---//
  int unsigned num_md_packets = 100;
  int unsigned num_apb_ops    = 20;
  
  //--- Handle al Entorno de Verificación ---//
  environment env;

  //--- Tarea Principal de Ejecución ---//
  // Recibe los handles de las interfaces virtuales desde top_tb
  virtual task run(virtual md_interface md_rx_vif,
                   virtual md_interface md_tx_vif,
                   virtual apb_interface apb_vif);
    
    $display("[%s] Iniciando la configuración del test...", name);

    //--- Fase 1: Configuración (Lectura de Plusargs) ---//
    // Sobrescribe los valores por defecto si se proporcionan en la línea de comandos
    if ($value$plusargs("NUM_MD_PACKETS=%d", num_md_packets))
      $display("[%s] Plusarg detectado: Se generarán %0d paquetes MD.", name, num_md_packets);

    if ($value$plusargs("NUM_APB_OPS=%d", num_apb_ops))
      $display("[%s] Plusarg detectado: Se generarán %0d operaciones APB.", name, num_apb_ops);
    
    //--- Fase 2: Construcción del Entorno ---//
    // Crea el objeto 'environment', pasándole las interfaces
    env = new(md_rx_vif, md_tx_vif, apb_vif);
    
    // Llama a la tarea de construcción del entorno, que crea todos los componentes
    env.build_phase();

    //--- Fase 3: Conexión Final y Configuración ---//
    // Pasa los valores configurados a los componentes correspondientes (en este caso, al generador)
    env.m_gen.num_md_packets_to_generate = this.num_md_packets;
    env.m_gen.num_apb_ops_to_generate = this.num_apb_ops;

    $display("[%s] Entorno construido y configurado. Iniciando la simulación...", name);
    
    //--- Fase 4: Ejecución ---//
    // Lanza todos los procesos en segundo plano (drivers, monitores, scoreboard)
    env.run_phase();
    env.m_gen.run();    
    // Ahora, explícitamente, corre la generación de estímulos y ESPERA a que termine.
    // Esto nos da un punto claro de finalización para el estímulo.
    
    $display("[%s] Toda la generación de estímulos ha terminado.", name);

    //--- Fase 5: Drenado y Finalización ---//
    // Damos un tiempo extra para que los últimos paquetes atraviesen el DUT
    // y sean procesados por el scoreboard.
    @(env.generation_done);
    $display("[%s] Esperando a que el scoreboard procese los paquetes restantes...", name);

    // CAMBIO: Reemplazamos el retardo fijo por una espera inteligente y con timeout.
    fork
      begin
        // Espera hasta que la función is_idle() del scoreboard devuelva 'true'.
        // Esto solo ocurrirá cuando todos los paquetes hayan fluido a través del DUT
        // y hayan sido verificados.
        #1ns
        wait(env.m_scoreboard.is_idle() == 1);
        $display("[%s] Scoreboard está inactivo. Drenaje completado.", name);
      end
      
      begin
        // Timeout de seguridad. Si el scoreboard nunca queda inactivo
        // (debido a un paquete perdido o un deadlock), la simulación terminará aquí.
        #2000ns; // Ajusta este valor según la duración esperada de tu test
        $error("[%s] ¡TIMEOUT! El scoreboard nunca quedó inactivo. La simulación puede estar colgada.", name);
      end
    join_any // Termina en cuanto uno de los dos bloques ('wait' o 'timeout') finalice.
    
    $display("[%s] Simulación completada. Generando reporte...", name);
    
    // Llama a la fase de reporte para mostrar los resultados
    env.report_phase();
    
    // Termina la simulación
    $finish();

  endtask

endclass

