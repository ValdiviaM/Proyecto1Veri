class pkt1;
  // Configuración general del test
  bit with_window;            // ventana habilitada o no
  int num_pkts;               // cantidad de transacciones a generar
  int delay_min_ns;           // delay mínimo entre paquetes
  int delay_max_ns;           // delay máximo entre paquetes

  // Constructor
  function new();
    with_window  = 0;
    num_pkts     = 20;
    delay_min_ns = 1;
    delay_max_ns = 10;
  endfunction
endclass
