default: sim

sim:
ifneq ($(fw),)
	@echo "--- Build FW ---"
ifeq ($(fw),coremark)
	make -C ./fw/$(fw) PORT_DIR=../coremark_port secondary-outputs
else
	make -C ./fw/$(fw) sim=1 clean all
endif
endif
	make -C sim $(target)

arch:
	make -C sim tests

clean:
	make -C ./fw/test clean
	make -C ./fw/dhrystone clean
	make -C sim clean

.PHONY: sim clean
$(V).SILENT:
