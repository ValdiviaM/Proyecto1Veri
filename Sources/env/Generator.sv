`include "pkt1.sv"   // bloque de test
`include "pkt2.sv"   // driver packet
`include "pkt6.sv"   // scoreboard packet
`include "md_driver.sv"
`include "apb_driver.sv"

class Generator;

  // Mailboxes for communication
  mailbox apb_mbx;
  mailbox md_mbx;
  mailbox scoreboard_mbx;

  // Drivers (pasados como handle)
  apb_driver apb_drv;
  md_driver  md_drv;

  // Config knobs
  int num_pkts = 20;
  bit with_window;
  int delay_min = 1, delay_max = 10;
  int size_options[]  = '{1,2,4};
  int offset_options[] = '{0,1,2,3};

  // Constructor
  function new(mailbox apb_mbx, mailbox md_mbx, mailbox scoreboard_mbx,
               apb_driver apb_drv, md_driver md_drv);
    this.apb_mbx        = apb_mbx;
    this.md_mbx         = md_mbx;
    this.scoreboard_mbx = scoreboard_mbx;
    this.apb_drv        = apb_drv;
    this.md_drv         = md_drv;
  endfunction

  // Main sequence
  task run(pkt1 input_pkt);
    pkt2 drv_pkt;
    pkt6 sb_pkt;

    $display("[%0t] [GEN] Starting generation...", $time);

    // === Step 0: Optional config from pkt1 ===
    this.with_window = input_pkt.with_window;

    // === Step 1: Generate APB config packet ===
    drv_pkt = new();
    drv_pkt.with_window = this.with_window;
    drv_pkt.addr        = 'h04;   // control reg example
    drv_pkt.write_en    = 1;
    drv_pkt.data        = new[1];
    drv_pkt.data[0]     = {31'b0, with_window};
    apb_mbx.put(drv_pkt);

    // === Step 2: Generate MD transactions ===
    for (int i = 0; i < num_pkts; i++) begin
      drv_pkt = new();
      void'(drv_pkt.randomize() with {
        drv_pkt.size   inside {size_options};
        drv_pkt.offset inside {offset_options};
        drv_pkt.inter_pkt_time_ns inside {[delay_min:delay_max]};
        drv_pkt.data.size() == drv_pkt.size.size();
      });

      // Generate expected scoreboard packet
      sb_pkt = new();
      sb_pkt.id   = i;
      sb_pkt.data = drv_pkt.data; // expected data
      scoreboard_mbx.put(sb_pkt);

      // Send to MD driver
      md_mbx.put(drv_pkt);

      $display("[%0t] [GEN] Sent pkt2 #%0d: size=%p, offset=%p, delay=%0d ns",
               $time, i, drv_pkt.size, drv_pkt.offset, drv_pkt.inter_pkt_time_ns);
    end

    $display("[%0t] [GEN] Packet generation complete", $time);
  endtask

endclass
