typedef class environment;

class generator;

  // Propiedades
  string name = "Generator";
  
  // Perillas para configurar desde el test
  int unsigned num_md_packets_to_generate = 100;
  int unsigned num_apb_ops_to_generate = 20;

  // Mailboxes para comunicarse con los drivers
  mailbox #(md_packet)        md_drv_mbx;
  mailbox #(apb_transaction)  apb_drv_mbx;

  protected environment m_env; 

  // Constructor
  function new(mailbox #(md_packet) md_drv_mbx, 
               mailbox #(apb_transaction) apb_drv_mbx,
               environment m_env); // << MODIFICAR
    this.md_drv_mbx = md_drv_mbx;
    this.apb_drv_mbx = apb_drv_mbx;
    this.m_env = m_env; // << AÑADIR: Asignar el handle
  endfunction

  // Tarea principal que inicia la generación de estímulos
  task run();
    $display("[%s] El generador ha comenzado.", name);
    // Lanza la generación de ambos tipos de estímulo en paralelo.
    // Esto permite que las escrituras de registros APB ocurran mientras
    // se están enviando paquetes de datos, un escenario de prueba más realista.
    fork
      run_md_stimulus();
      run_apb_stimulus();
    join
    $display("[%s] El generador ha terminado de crear todos los estímulos.", name);
    m_env.report_generation_done(num_md_packets_to_generate);
  endtask

  // Tarea que genera el número configurado de paquetes de datos MD
  protected task run_md_stimulus();
    repeat (num_md_packets_to_generate) begin
      md_packet pkt = new();
      
      // Aleatoriza el paquete. Si falla, es un error fatal del testbench.
      if (!pkt.randomize()) begin
        $fatal(1, "[%s] ¡Falló la aleatorización del MD Packet!", name);
      end
      
      $display("[%s] Generado -> %s", name, pkt.display());
      
      // Coloca el paquete aleatorizado en el mailbox del driver de MD
      md_drv_mbx.put(pkt);
    end
  endtask

  // Tarea que genera el número configurado de operaciones APB
  protected task run_apb_stimulus();
    // Agregamos un pequeño retardo inicial para no competir con el reset
    #100ns;
    repeat (num_apb_ops_to_generate) begin
      apb_transaction tx = new();
      
      if (!tx.randomize()) begin
        $fatal(1, "[%s] ¡Falló la aleatorización de la APB Transaction!", name);
      end
      
      $display("[%s] Generado -> %s", name, tx.display());

      // Coloca la transacción aleatorizada en el mailbox del driver de APB
      apb_drv_mbx.put(tx);

      // Espera un tiempo aleatorio antes de la siguiente operación de registro
      #(($urandom_range(50, 200)) * 1ns);
    end
  endtask

endclass
