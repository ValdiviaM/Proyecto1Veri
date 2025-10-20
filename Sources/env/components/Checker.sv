  class Checker;
    function new(int data_width = 32, int fifo_depth = 8);
    endfunction
    function void report();
      $display("--- Checker Report ---");
    endfunction
  endclass