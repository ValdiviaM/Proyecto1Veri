`include "apb_if.sv"
`include "pkt4.sv"

class apb_monitor;
  virtual apb_if.Transactor apb_vif;
  mailbox #(pkt4) actual_mbx;
  pkt4 dut_state; // Handle al estado compartido del DUT

  // Mapeo de registros (ejemplo, debe coincidir con el DUT)
  localparam ADDR_CTRL   = 16'h00;
  localparam ADDR_STATUS = 16'h04;
  localparam ADDR_IRQ_EN = 16'h08;

  function new(virtual apb_if.Transactor apb_vif, mailbox #(pkt4) actual_mbx, pkt4 dut_state);
    this.apb_vif = apb_vif;
    this.actual_mbx = actual_mbx;
    this.dut_state = dut_state;
  endfunction

  task run();
    forever begin
      @(apb_vif.master_cb); // Sincronizarse con el reloj

      // Detectar el final de una transacción APB (fase ACCESS con pready=1)
      if (apb_vif.master_cb.psel && apb_vif.master_cb.penable && apb_vif.master_cb.pready) begin
        
        // Si es una transacción de escritura, actualizamos nuestro modelo de estado
        if (apb_vif.master_cb.pwrite) begin
          automatic logic [31:0] wdata = apb_vif.master_cb.pwdata;
          
          case (apb_vif.master_cb.paddr)
            ADDR_CTRL: begin
              dut_state.set_aligment(wdata[10:8], wdata[1:0]);
              if (wdata[16]) dut_state.cnt_drop_cleared = 1; else dut_state.cnt_drop_cleared = 0;
              $display("[APB_MON] Write to CTRL: size=%0d, offset=%0d, clear=%b", 
                       wdata[10:8], wdata[1:0], wdata[16]);
            end
            ADDR_IRQ_EN: begin
              dut_state.irq_enable = wdata[4:0];
              $display("[APB_MON] Write to IRQ_ENABLE: 0x%0h", wdata[4:0]);
            end
          endcase
          
          // Enviar el estado actualizado al checker
          actual_mbx.put(dut_state);
        end
      end
    end
  endtask
endclass