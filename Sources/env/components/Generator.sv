class generator;

  // Propiedades
  string name = "Generator";
  
  // Perillas para configurar desde el test
  int unsigned num_md_packets_to_generate = 100;
  int unsigned num_apb_ops_to_generate = 20;

  // Mailboxes para comunicarse con los drivers
  mailbox #(md_packet)        md_drv_mbx;
  mailbox #(apb_transaction)  apb_drv_mbx;
  
  // Handle para el evento que se recibirá desde el entorno
  event generation_done_event;

  // Constructor (sin cambios)
  function new(mailbox #(md_packet) md_drv_mbx, mailbox #(apb_transaction) apb_drv_mbx);
    this.md_drv_mbx = md_drv_mbx;
    this.apb_drv_mbx = apb_drv_mbx;
  endfunction

  // Tarea principal que inicia la generación de estímulos
  task run();
    $display("[%s] El generador ha comenzado a crear estímulos.", name);
    
    // Tu lógica original era la correcta: lanzar ambas tareas en paralelo
    // y esperar a que la más lenta (APB) termine.
    fork
      run_md_stimulus();
      run_apb_stimulus();
    join
    
    $display("[%s] El generador ha terminado de poner todos los estímulos en los mailboxes.", name);
    
    // *** CORRECCIÓN CLAVE ***
    // Añadimos un retardo mínimo aquí. Esto rompe la condición de carrera.
    // Le da al resto del entorno un ciclo de simulación para reaccionar a la
    // ÚLTIMA transacción que se acaba de generar, antes de que el test
    // empiece a comprobar si el scoreboard está inactivo.
    #1ns;
    
    // Ahora, disparamos el evento.
    -> generation_done_event;
    
  endtask

  // Tarea que genera el número configurado de paquetes de datos MD (sin cambios)
  protected task run_md_stimulus();
    repeat (num_md_packets_to_generate) begin
      md_packet pkt = new();
      if (!pkt.randomize()) begin
        $fatal(1, "[%s] ¡Falló la aleatorización del MD Packet!", name);
      end
      // $display("[%s] Generado -> %s", name, pkt.display());
      md_drv_mbx.put(pkt);
    end
  endtask

  // Tarea que genera el número configurado de operaciones APB (sin cambios)
  protected task run_apb_stimulus();
    #100ns;
    repeat (num_apb_ops_to_generate) begin
      apb_transaction tx = new();
      if (!tx.randomize()) begin
        $fatal(1, "[%s] ¡Falló la aleatorización de la APB Transaction!", name);
      end
      // $display("[%s] Generado -> %s", name, tx.display());
      apb_drv_mbx.put(tx);
      #(($urandom_range(50, 200)) * 1ns);
    end
  endtask

endclass
