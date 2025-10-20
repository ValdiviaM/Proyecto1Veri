`include "pkt1.sv"
`include "packets.sv" // Contains the cleaner apb_pkt and md_pkt
`include "pkt6.sv"

// This Generator acts as both a stimulus generator and a predictor.
// It sends input transactions to the drivers and predicted output
// transactions (pkt6) to the scoreboard.
class Generator;

  // Mailboxes for communication
  mailbox #(apb_pkt) apb_driver_mbx;
  mailbox #(md_pkt)  md_driver_mbx;
  mailbox #(pkt6)   scoreboard_mbx; // Communication to Scoreboard

  // Internal state to track DUT configuration for prediction
  local bit [2:0] dut_cfg_size;
  local bit [1:0] dut_cfg_offset;
  local bit       dut_cfg_enabled;
  
  int transaction_id_counter;

  // Constructor
  function new(mailbox #(apb_pkt) apb_driver_mbx,
               mailbox #(md_pkt)  md_driver_mbx,
               mailbox #(pkt6)   scoreboard_mbx);
    this.apb_driver_mbx = apb_driver_mbx;
    this.md_driver_mbx  = md_driver_mbx;
    this.scoreboard_mbx = scoreboard_mbx;
    
    // Default configuration at reset
    this.dut_cfg_enabled = 0;
    this.dut_cfg_size    = 3'd4;
    this.dut_cfg_offset  = 2'd0;
    this.transaction_id_counter = 0;
  endfunction

  // Main task driven by the test configuration (pkt1)
  task run(pkt1 test_cfg);
    $display("[%0t] [GEN] Starting generation based on test config...", $time);

    // === Step 1: Configure the DUT based on the test ===
    // We create the configuration word and send it via APB.
    // We also update our internal state for future predictions.
    bit [31:0] ctrl_reg_data;
    dut_cfg_enabled = 1; // Assuming test wants to enable the DUT
    dut_cfg_size    = 4; // Example: Set align to 4 bytes
    dut_cfg_offset  = 0; // Example: Set offset to 0
    
    ctrl_reg_data = {15'b0, dut_cfg_enabled, 8'b0, dut_cfg_size, 6'b0, dut_cfg_offset};
    send_apb_write('h00, ctrl_reg_data); // Write to Control Register at address 0x00

    // === Step 2: Generate MD transactions ===
    for (int i = 0; i < test_cfg.num_pkts; i++) begin
      md_pkt input_stimulus_pkt = new();
      pkt6   expected_output_pkt;

      // Randomize the input packet using constraints from the test
      void'(input_stimulus_pkt.randomize() with {
        inter_pkt_time_ns inside {[test_cfg.delay_min_ns : test_cfg.delay_max_ns]};
      });

      // A. Send the stimulus to the driver to be sent to the DUT
      md_driver_mbx.put(input_stimulus_pkt);

      // B. Predict the corresponding output
      expected_output_pkt = this.predict_output(input_stimulus_pkt);

      // C. Send the predicted output to the scoreboard
      scoreboard_mbx.put(expected_output_pkt);

      $display("[%0t] [GEN] Sent input pkt and predicted output for ID %0d", $time, expected_output_pkt.id);
    end

    $display("[%0t] [GEN] Packet generation complete.", $time);
  endtask

  // --- Helper Tasks ---

  // Sends an APB write transaction
  task send_apb_write(bit [15:0] addr, bit [31:0] data);
    apb_pkt pkt = new();
    pkt.write_en = 1;
    pkt.addr = addr;
    pkt.data = data;
    apb_driver_mbx.put(pkt);
    $display("[%0t] [GEN] Sent APB Write: addr=0x%h, data=0x%h. Updating internal state.", $time, addr, data);
  endtask

  // PREDICTION FUNCTION: Models the DUT's behavior
  function pkt6 predict_output(md_pkt input_pkt);
    pkt6 predicted_pkt = new();
    predicted_pkt.id = transaction_id_counter++;

    // This is where the behavioral model of the aligner lives.
    // It must exactly match the DUT's specification.
    //
    // EXAMPLE LOGIC:
    // - If the DUT is not enabled, the output packet should be empty.
    // - Iterate through each word of the input packet.
    // - If the input word's size/offset matches the DUT's configuration,
    //   it is a "legal" transfer and should appear on the output.
    // - If it does not match, it is "illegal" and should be dropped (not added to the output).

    if (!dut_cfg_enabled) begin
      return predicted_pkt; // Return empty packet if DUT is off
    end

    foreach (input_pkt.data[i]) begin
      bit is_legal_transfer;
      
      // Check if the transfer is legal based on our tracked configuration
      is_legal_transfer = (input_pkt.size[i] == dut_cfg_size) && (input_pkt.offset[i] == dut_cfg_offset);

      if (is_legal_transfer) begin
        // If legal, the data passes through. Add it to the expected output.
        predicted_pkt.data.push_back(input_pkt.data[i]);
        predicted_pkt.size.push_back(input_pkt.size[i]);
        predicted_pkt.offset.push_back(input_pkt.offset[i]);
      end
      // If not legal, we do nothing, effectively "dropping" the word,
      // which is what we expect the DUT to do.
    end
    
    return predicted_pkt;
  endfunction

endclass