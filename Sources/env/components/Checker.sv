class checker;
  
  string name = "Checker";
  int unsigned mismatch_count = 0;

  // La función principal: toma dos paquetes y devuelve '1' si coinciden, '0' si no.
  function bit compare(md_packet expected, md_packet actual);
    bit is_match = 1'b1;

    if (expected.data !== actual.data) begin
      $error("[%s] MISMATCH en DATA. Esperado: %h, Recibido: %h", name, expected.data, actual.data);
      is_match = 1'b0;
    end
    
    if (expected.size !== actual.size) begin
      $error("[%s] MISMATCH en SIZE. Esperado: %d, Recibido: %d", name, expected.size, actual.size);
      is_match = 1'b0;
    end
    
    if (expected.offset !== actual.offset) begin
      $error("[%s] MISMATCH en OFFSET. Esperado: %d, Recibido: %d", name, expected.offset, actual.offset);
      is_match = 1'b0;
    end
    
    if(!is_match) begin
        mismatch_count++;
    end

    return is_match;
  endfunction

endclass
