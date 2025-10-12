`include "pkt2.sv"   // configuration / timing packet
`include "pkt3.sv"   // transaction packet (input/output)
`include "pkt6.sv"   // scoreboard packet
`include "md_driver.sv"
`include "apb_driver.sv"

class Generator;

  // Mailboxes for communication with drivers and scoreboard
  mailbox apb_mbx;
  mailbox md_mbx;
  mailbox scoreboard_mbx;

  // Control knobs
  int num_pkts = 20;
  bit with_window;
  int delay_min = 1, delay_max = 10;
  int size_options[]  = '{1, 2, 4};
  int offset_options[] = '{0, 1, 2, 3};

  // Drivers (created externally or passed as handles)
  apb_driver apb_drv;
  md_driver  md_drv;

  function new(mailbox apb_mbx, mailbox md_mbx, mailbox scoreboard_mbx,
               apb_driver apb_drv, md_driver md_drv);
    this.apb_mbx        = apb_mbx;
    this.md_mbx         = md_mbx;
    this.scoreboard_mbx = scoreboard_mbx;
    this.apb_drv        = apb_drv;
    this.md_drv         = md_drv;
  endfunction

  // Main sequence
  task run();
    pkt2 cfg_pkt;
    pkt3 tr_pkt;

    $display("[%0t] [GEN] Starting packet generation...", $time);

    // Step 1: Create configuration packet
    cfg_pkt = new();
    void'(cfg_pkt.randomize() with {
      cfg_pkt.with_window == $urandom_range(0, 1);
      cfg_pkt.delay_cycles inside {[delay_min:delay_max]};
    });
    this.with_window = cfg_pkt.with_window;

    // Configure DUT via APB
    pkt3 apb_cfg = new();
    apb_cfg.addr     = 'h04; // Example control reg
    apb_cfg.write_en = 1;
    apb_cfg.wdata    = {31'b0, with_window};
    apb_mbx.put(apb_cfg);

    // Step 2: Generate MD transactions
    for (int i = 0; i < num_pkts; i++) begin
      tr_pkt = new();

      void'(tr_pkt.randomize() with {
        tr_pkt.size   inside {size_options};
        tr_pkt.offset inside {offset_options};
        tr_pkt.delay_cycles inside {[delay_min:delay_max]};
        tr_pkt.data_in.size() == tr_pkt.size;
      });

      // Optionally create expected pkt6 for scoreboard
      pkt6 expected = new();
      expected.id = i;
      expected.data = tr_pkt.data_in;
      scoreboard_mbx.put(expected);

      // Send to MD driver
      md_mbx.put(tr_pkt);

      $display("[%0t] [GEN] Sent pkt %0d: size=%0d, offset=%0d, delay=%0d",
               $time, i, tr_pkt.size, tr_pkt.offset, tr_pkt.delay_cycles);
    end

    $display("[%0t] [GEN] Generation complete", $time);
  endtask

endclass
