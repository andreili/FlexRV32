PROJ_NAME = dhrystone
C_FLAGS = -DHZ=117000000 -DDRUNS=500 -DREG=register -DNDEBUG

OBJS = init.o uart.o xprintf.o sim.o dhry_1.o dhry_2.o

include ../Makefile.include

# Other Targets
clean:
	$(RM) $(WORK_DIR)

$(WORK_DIR):
	mkdir -p  $(WORK_DIR)

$(V).SILENT:
