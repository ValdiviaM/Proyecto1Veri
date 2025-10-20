class pkt6;
    int id;
    bit [31:0] data[$];
    bit [2:0]  size[$];
    bit [1:0]  offset[$];
    bit is_last; // <-- ADD THIS FLAG

    function new();
      id = 0;
      data = {};
      size = {};
      offset = {};
      is_last = 0; // Default to 0
    endfunction
  endclass