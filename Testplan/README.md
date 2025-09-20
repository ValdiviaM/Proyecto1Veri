# Testplan

## Casos de uso común
- Aserciones para APB
- Aserciones para MD
  
### Aleatorizando:
- Eventos Alineamiento
- Eventos de Reset
- Datos de entrada
- Tamaños de entrada
- Offset de la entrada
- Tiempos de envío entre paquetes
- Numero de transacciones
- Eventos de clear
- Profundidad de la FIFO
- Offset de control (0, 1, 2, 3)
- Tamaño datos alineados (1, 2, 4)
- Revisión de registro de status

## Casos de esquina:
- Datos mal alineados
- Llenar y vaciar FIFO_RX y FIFO_TX
- Llegar a MAX_DROP errores de alineación y revisar flag
- Valores inválidos de los registros
- Uso erróneo de APB
