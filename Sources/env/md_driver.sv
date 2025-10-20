`include "pkt2.sv"
`include "md_if.sv"

class md_driver;
  virtual md_if.Transactor md_vif;

  function new(virtual md_if.Transactor md_vif);
    this.md_vif = md_vif;
  endfunction

  // Tarea para manejar el canal de recepción del Testbench (salida del DUT)
  // Esta tarea debe ser lanzada en un fork...join_none al inicio del test.
  task run_tx_handler();
    // Por defecto, siempre estamos listos para recibir datos del DUT.
    // Esto es crucial, sin esto el DUT se bloquearía.
    md_vif.transactor_cb.md_tx_ready <= 1'b1;
    md_vif.transactor_cb.md_tx_err   <= 1'b0; // No inyectamos errores por defecto

    // Opcional: Para pruebas más avanzadas, se puede aleatorizar la aserción de 'ready'
    // para crear "stalls" (pausas) y probar la lógica de back-pressure del DUT.
    // Ejemplo:
    // forever begin
    //   if ($urandom_range(0, 9) < 8) begin // 80% de probabilidad de estar listo
    //     md_vif.transactor_cb.md_tx_ready <= 1'b1;
    //     @(md_vif.transactor_cb);
    //   end else begin
    //     md_vif.transactor_cb.md_tx_ready <= 1'b0;
    //     repeat($urandom_range(1, 5)) @(md_vif.transactor_cb);
    //   end
    // end
  endtask

  // Tarea principal para enviar un paquete (pkt2) al DUT por el canal RX.
  task drive(pkt2 p, real clk_period_ns);
    // 1. Delay inicial entre paquetes
    int delay_cycles = (p.inter_pkt_time_ns / clk_period_ns);
    if (delay_cycles > 0) begin
      // Asegurarse de que 'valid' esté bajo durante el delay
      md_vif.transactor_cb.md_rx_valid <= 1'b0;
      repeat(delay_cycles) @(posedge md_vif.clk);
    end

    // 2. Bucle de envío de datos con handshake CORRECTO
    foreach(p.data[i]) begin
      md_vif.transactor_cb.md_rx_valid  <= 1'b1;
      md_vif.transactor_cb.md_rx_data   <= p.data[i];
      md_vif.transactor_cb.md_rx_size   <= p.size[i];
      md_vif.transactor_cb.md_rx_offset <= p.offset[i];

      // Esperar hasta que el DUT acepte los datos (valid=1 y ready=1 en el mismo ciclo)
      // Esta es la forma robusta de implementar el handshake.
      do begin
        @(md_vif.transactor_cb);
      end while (!md_vif.transactor_cb.md_rx_ready);
    end

    // 3. Finalizar la transacción
    md_vif.transactor_cb.md_rx_valid <= 1'b0;
    // Dejar los buses de datos en un estado conocido para limpieza en el waveform
    md_vif.transactor_cb.md_rx_data   <= '0;
    md_vif.transactor_cb.md_rx_size   <= '0;
    md_vif.transactor_cb.md_rx_offset <= '0;
    @(md_vif.transactor_cb); // Esperar un ciclo para que el DUT vea valid=0

  endtask
endclass