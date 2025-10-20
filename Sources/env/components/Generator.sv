class Generator;
    mailbox #(apb_pkt) apb_driver_mbx;
    mailbox #(bit)     apb_response_mbx;
    mailbox #(md_pkt)  md_driver_mbx;
    mailbox #(pkt6)   scoreboard_mbx;

    local bit [2:0] dut_cfg_size;
    local bit [1:0] dut_cfg_offset;
    local bit       dut_cfg_enabled;
    local bit [1:0] dut_cfg_encoded_offset;
    int transaction_id_counter;

    function new(mailbox #(apb_pkt) apb_driver_mbx, 
                mailbox #(bit)     apb_response_mbx,
                mailbox #(md_pkt)  md_driver_mbx, 
                mailbox #(pkt6)   scoreboard_mbx);
      this.apb_driver_mbx   = apb_driver_mbx;
      this.apb_response_mbx = apb_response_mbx; // <-- STORE IT
      this.md_driver_mbx    = md_driver_mbx;
      this.scoreboard_mbx   = scoreboard_mbx;
      this.dut_cfg_enabled = 0;
      this.dut_cfg_size    = 3'd4;
      this.dut_cfg_offset  = 2'd0;
      this.transaction_id_counter = 0;
    endfunction

  task configure_dut(bit [2:0] size, bit [1:0] offset, bit [1:0] encoded_offset, bit enabled);
    bit [31:0] ctrl_reg_data;

    // Store the configuration locally for the predictor to use
    this.dut_cfg_enabled = enabled;
    this.dut_cfg_size    = size;
    this.dut_cfg_offset  = offset; // Store the REAL byte offset for the predictor
    this.dut_cfg_encoded_offset = encoded_offset; // Store the ENCODED offset for the DUT

    $display("[Generator] Configuring DUT for size=%0d, offset=%0d, enabled=%0d", size, offset, enabled);

    // Assemble the control word and send it via the blocking APB write
    ctrl_reg_data = {12'b0, dut_cfg_enabled, 8'b0, dut_cfg_size, 6'b0, dut_cfg_encoded_offset};
    send_apb_write('h00, ctrl_reg_data);
  endtask

    task run(pkt1 test_cfg);
    // Loop to generate stimulus
    for (int i = 0; i < test_cfg.num_pkts; i++) begin
      md_pkt input_stimulus_pkt = new();
      pkt6   expected_output_pkt;

      void'(input_stimulus_pkt.randomize() with {
        inter_pkt_time_ns inside {[test_cfg.delay_min_ns : test_cfg.delay_max_ns]};
      });

      md_driver_mbx.put(input_stimulus_pkt);
      expected_output_pkt = this.predict_output(input_stimulus_pkt);
      scoreboard_mbx.put(expected_output_pkt);
     

    end
    begin
      pkt6 final_pkt = new();
      final_pkt.is_last = 1;
      $display("[Generator] All stimulus sent. Sending final packet to scoreboard.");
      scoreboard_mbx.put(final_pkt);
    end
  endtask

    task send_apb_write(bit [15:0] addr, bit [31:0] data);
      apb_pkt pkt = new();
      bit dummy;
      pkt.write_en = 1;
      pkt.addr = addr;
      pkt.data = data;
      apb_driver_mbx.put(pkt);
      apb_response_mbx.get(dummy);
    endtask

    function pkt6 predict_output(md_pkt input_pkt);

        pkt6 predicted_pkt = new();
        bit is_legal_transfer;
        int expected_byte_size;
        $display("[PRED CFG] dut_cfg_offset=%0d, dut_cfg_size=%0d", dut_cfg_offset, dut_cfg_size);

        predicted_pkt.id = transaction_id_counter++;
        if (!dut_cfg_enabled) return predicted_pkt;

        // Map encoded DUT size to actual byte-size
        case (dut_cfg_size)
          0: expected_byte_size = 1;
          1: expected_byte_size = 2;
          2: expected_byte_size = 4;
          default: expected_byte_size = 0;
        endcase

        foreach (input_pkt.data[i]) begin
          is_legal_transfer = (input_pkt.size[i] == expected_byte_size) &&
                              (input_pkt.offset[i] == dut_cfg_offset);

          if (is_legal_transfer) begin
            bit [31:0] input_word;
            bit [31:0] predicted_word;
            int byte_shift;
            bit [31:0] mask;

            input_word = input_pkt.data[i];
            predicted_word = 32'b0;

            // compute shift in bits to align the transferred bytes to LSB
            byte_shift = input_pkt.offset[i] * 8;

            // mask depends on transfer size
            case (input_pkt.size[i])
              1: mask = 32'hFF;
              2: mask = 32'hFFFF;
              4: mask = 32'hFFFF_FFFF;
              default: mask = 32'h0;
            endcase

            // extract the byte/halfword/word from the input word using shift+mask
            predicted_word = (input_word >> byte_shift) & mask;
 
            // store predicted information (use REAL byte offset that the DUT will place)
            predicted_pkt.data.push_back(predicted_word);
            predicted_pkt.size.push_back(input_pkt.size[i]);     // bytes (1/2/4)
            predicted_pkt.offset.push_back(0);
     // the DUT configured byte offset
            $display("[GEN PRED] pkt_id=%0d input_word=0x%08h size=%0d offset=%0d -> predicted_word=0x%08h (stored_offset=%0d)",
                    predicted_pkt.id, input_word, input_pkt.size[i], input_pkt.offset[i], predicted_word, dut_cfg_offset);
          end
        end
        return predicted_pkt;
    endfunction
  endclass