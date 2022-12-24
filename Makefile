default: sim

sim:
ifneq ($(fw),)
	make -C ./fw/$(fw) sim=1 clean all
endif
	make -C sim $(target)

arch:
	make -C sim tests

clean:
	make -C ./fw/test clean
	make -C ./fw/dhrystone clean
	make -C sim clean

.PHONY: sim clean
