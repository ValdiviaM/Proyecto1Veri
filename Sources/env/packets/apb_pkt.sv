  class apb_pkt extends pkt_base;
    rand bit        write_en;
    rand bit [15:0] addr;
    rand bit [31:0] data;
  endclass