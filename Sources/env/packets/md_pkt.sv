class md_pkt extends pkt_base;
    rand int unsigned num_words = 1;
    rand bit [31:0] data[];
    rand bit [2:0]  size[];
    rand bit [1:0]  offset[];

    constraint c_sizes {
      num_words inside {[1:16]};
      data.size() == num_words;
      size.size() == num_words;
      offset.size() == num_words;
      foreach(size[i]) size[i] inside {3'd1, 3'd2, 3'd4};
    }

    constraint c_legal_combinations {
      foreach(data[i]) {
        (size[i] == 2) -> (offset[i] % 2 == 0);
        (size[i] == 4) -> (offset[i] == 0);
      }
    }
  endclass