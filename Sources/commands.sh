source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh;

rm -rfv `ls |grep -v ".*\.sv\|.*\.sh\|^figures$"`;

vcs -Mupdate -incdir /dut -incdir /env tb.sv  -o salida -full64 -debug_all -sverilog -l log_test +lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert;

