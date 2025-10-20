  class pkt_base;
    rand int unsigned inter_pkt_time_ns;
    constraint c_delay { inter_pkt_time_ns inside {[0:10000]}; }
  endclass