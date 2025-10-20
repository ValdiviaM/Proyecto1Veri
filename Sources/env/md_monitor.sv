`include "md_if.sv"
`include "pkt4.sv"

class md_monitor;
  virtual md_if.Transactor md_vif;
  mailbox #(pkt4) actual_mbx;
  pkt4 dut_state; // Handle al estado compartido del DUT

  function new(virtual md_if.Transactor md_vif, mailbox #(pkt4) actual_mbx, pkt4 dut_state);
    this.md_vif = md_vif;
    this.actual_mbx = actual_mbx;
    this.dut_state = dut_state;
  endfunction

  // Tarea principal para lanzar los monitores de cada canal
  task run();
    fork
      monitor_rx();
      monitor_tx();
    join_none
  endtask

  // Monitor para el canal de entrada al DUT (RX)
  task monitor_rx();
    forever begin
      @(md_vif.transactor_cb);

      // Detectar una transferencia en el canal RX
      if (md_vif.transactor_cb.md_rx_valid && md_vif.transactor_cb.md_rx_ready) begin
        $display("[MD_MON_RX] Detected RX transfer.");
        
        // Comprobar si la transferencia es legal según la configuración actual
        // (Esta lógica la tienes en el checker, la replicamos aquí para modelar)
        // bool is_legal = is_rx_transfer_legal(md_vif.transactor_cb.md_rx_size, ...);
        
        // Aquí simplificamos: asumimos que md_rx_err nos dice si fue ilegal
        if (md_vif.transactor_cb.md_rx_err) begin
          if (dut_state.cnt_drop < 255) begin
            dut_state.cnt_drop++;
          end
        end else {
          // Si es legal, modelamos la FIFO
          // dut_state.rx_fifo_level++; // Se necesita un modelo más complejo
        }
        
        // Clonamos el estado para no crear race conditions con el checker
        pkt4 current_state = new dut_state;
        actual_mbx.put(current_state);
      end
    end
  endtask

  // Monitor para el canal de salida del DUT (TX)
  task monitor_tx();
    forever begin
      @(md_vif.transactor_cb);

      // Detectar una transferencia en el canal TX
      if (md_vif.transactor_cb.md_tx_valid && md_vif.transactor_cb.md_tx_ready) begin
        $display("[MD_MON_TX] Detected TX transfer.");

        // Modelar el decremento de la FIFO de salida
        // dut_state.tx_fifo_level--; // Se necesita un modelo más complejo

        // Clonamos el estado y lo enviamos
        pkt4 current_state = new dut_state;
        actual_mbx.put(current_state);
      end
    end
  endtask
endclass