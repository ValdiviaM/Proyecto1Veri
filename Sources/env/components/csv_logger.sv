class csv_logger;
  
  protected int file_handle;
  protected string file_name;

  // Constructor: abre el archivo y escribe la cabecera
  function new(string file_name = "simulation_log.csv");
    this.file_name = file_name;
    file_handle = $fopen(this.file_name, "w");
    if (file_handle == 0) begin
      $fatal(2, "No se pudo abrir el archivo CSV: %s", file_name);
    end
    
    // Escribe la cabecera del archivo
    $fdisplay(file_handle, "Timestamp,Result,Actual_Data,Actual_Size,Actual_Offset,Expected_Data,Expected_Size,Expected_Offset");
  endfunction

  // Tarea para escribir una nueva entrada en el log
  task log_entry(bit match, md_packet actual, md_packet expected);
    string result_str = match ? "MATCH" : "MISMATCH";
    
    if (file_handle != 0) begin
      $fdisplay(file_handle, "%0t,%s,%h,%d,%d,%h,%d,%d",
                $time,
                result_str,
                actual.data, actual.size, actual.offset,
                expected.data, expected.size, expected.offset);
    end
  endtask

  // Función para cerrar el archivo (se llamará al final de la simulación)
  function void close();
    if (file_handle != 0) begin
      $fclose(file_handle);
      $display("[CSV Logger] Reporte guardado en: %s", file_name);
    end
  endfunction

endclass