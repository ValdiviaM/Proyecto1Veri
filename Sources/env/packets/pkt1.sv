  class pkt1;
    bit with_window;
    int num_pkts;
    int delay_min_ns;
    int delay_max_ns;

    function new();
      with_window  = 0;
      num_pkts     = 20;
      delay_min_ns = 1;
      delay_max_ns = 10;
    endfunction
  endclass