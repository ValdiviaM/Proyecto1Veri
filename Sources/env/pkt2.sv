class pkt2;
  // Timing
  rand int unsigned inter_pkt_time_ns;

  // Window
  rand bit with_window;

  // Data arrays
  rand bit [31:0] data[];       // arreglo de palabras
  rand bit [2:0]  size[];       // bytes: 1,2,4
  rand bit [1:0]  offset[];     // 0..3

  // Optional: capture output from DUT
  bit [31:0] data_out[];        // mismo tamaño que data

  // Optional: for APB transactions
  bit write_en;
  bit [31:0] addr;

  // Constructor
  function new(); endfunction

  // Post-randomization coherence
  function void post_randomize();
    if (data.size() == 0) begin
      data = new[1];
      size = new[1];
      offset = new[1];
      data[0] = $urandom();
      size[0] = 3'd4;
      offset[0] = 2'd0;
    end

    // Ensure output array same size
    data_out = new[data.size()];
  endfunction

  // Constraints
  constraint c_sizes {
    foreach(size[i]) size[i] inside {3'd1, 3'd2, 3'd4};
    foreach(offset[i]) offset[i] inside {[0:3]};
    inter_pkt_time_ns inside {[0:10000]};
  }
endclass
