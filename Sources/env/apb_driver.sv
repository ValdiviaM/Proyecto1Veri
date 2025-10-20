`include "pkt2.sv"
`include "apb_if.sv"

class apb_driver;
  virtual apb_if.Transactor apb_vif;

  function new(virtual apb_if.Transactor apb_vif);
    this.apb_vif = apb_vif;
  endfunction

  task drive(pkt2 p, real clk_period_ns);
    // Convertir tiempo a ciclos de reloj
    int delay_cycles = (p.inter_pkt_time_ns / clk_period_ns);
    if (delay_cycles > 0) begin
      repeat(delay_cycles) @(posedge apb_vif.pclk);
    end

    // --- Inicio de la transacción APB usando el Clocking Block ---

    // Fase de SETUP
    apb_vif.master_cb.psel   <= 1'b1;
    apb_vif.master_cb.paddr  <= p.addr;
    apb_vif.master_cb.pwrite <= p.write_en;
    apb_vif.master_cb.pwdata <= p.data[0];
    apb_vif.master_cb.penable <= 1'b0;
    @(apb_vif.master_cb); // Avanzar un ciclo de reloj

    // Fase de ACCESS
    apb_vif.master_cb.penable <= 1'b1;

    // Esperar a que el esclavo esté listo (pready=1)
    // Esta es la forma segura y síncrona de esperar
    while (!apb_vif.master_cb.pready) begin
      @(apb_vif.master_cb);
    end

    // En el ciclo que pready es 1, capturamos los datos si es una lectura
    if (!p.write_en) begin
      p.data_out = apb_vif.master_cb.prdata;
    end
    @(apb_vif.master_cb); // Avanzar un ciclo para terminar la fase de ACCESS

    // Fase de IDLE
    apb_vif.master_cb.psel    <= 1'b0;
    apb_vif.master_cb.penable <= 1'b0;
    
    // Dejar las señales de datos en un estado inactivo para limpieza en el waveform
    apb_vif.master_cb.paddr   <= '0;
    apb_vif.master_cb.pwrite  <= 1'b0;
    apb_vif.master_cb.pwdata  <= '0;

  endtask
endclass