`include "pkt2.sv"
`include "md_if.sv"

class md_driver;
  virtual md_if.Transactor md_vif;
  mailbox #(md_pkt) drv_mbx;

  function new(virtual md_if.Transactor md_vif, mailbox #(md_pkt) drv_mbx);
    this.md_vif = md_vif;
    this.drv_mbx = drv_mbx;
  endfunction
  
  task run();
    fork
    run_tx_handler(); // Manages md_tx_ready
    run_rx_sender(); // Sends md_rx data
    join_none
    endtask
    task run_rx_sender();
    forever begin
    md_pkt pkt;
    drv_mbx.get(pkt); // Wait for a transaction from the generator
    drive_transaction(pkt);
  end
  endtask
  
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