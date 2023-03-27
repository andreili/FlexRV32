default: all

sim:
ifneq ($(fw),)
	@echo ">>> Build FW <<<"
ifeq ($(fw),coremark)
	make -C ./fw/$(fw) PORT_DIR=../coremark_port secondary-outputs
else
	make -C ./fw/$(fw) sim=1 clean all
endif
endif
	make -C sim $(target)

arch:
	@echo ">>> Run architecture tests <<<"
	make -C sim tests

bit:
	make -C proj/quartus
	python sim_common/results.py results.json html

clean:
	@echo ">>> Clean all <<<"
	make -C ./fw/test clean
	make -C ./fw/dhrystone clean
	make -C sim clean
	make -C proj/quartus clean

wave:
	gtkwave -a sim/top.gtkw -6 -7 --rcfile=sim/gtkwaverc sim/run/logs_top/wave.fst

results:
	python sim_common/results.py results.json parse_quartus proj/quartus/output_files/riscv_soc
	python sim_common/results.py results.json html

all: clean arch bit results

.PHONY: sim clean
$(V).SILENT:
