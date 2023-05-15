
OUTFLAG= -o
PROJ_NAME = coremark

OBJS = init.o uart.o sim.o core_portme.o ee_printf.o core_list_join.o core_main.o core_matrix.o core_state.o core_util.o
C_FLAGS = -I$(PORT_DIR) -I../coremark/ -I../common/ -DHZ=75000000 -DITERATIONS=1200
C_FLAGS += -DPERFORMANCE_RUN=1
WORK_DIR = $(PORT_DIR)/out
OPATH = $(WORK_DIR)

include ../Makefile.include

CF := $(C_FLAGS)
C_FLAGS += -DFLAGS_STR="\"$(CF)\""

EXE = .el

LFLAGS_END = 
# Flag : PORT_SRCS
# 	Port specific source files can be added here
#	You may also need cvt.c if the fcvt functions are not provided as intrinsics by your compiler!
PORT_SRCS = $(PORT_DIR)/core_portme.c $(PORT_DIR)/ee_printf.c ../common/uart.c ../common/sim.c ../common/init.S
vpath %.c $(PORT_DIR)
vpath %.s $(PORT_DIR)

# Target : port_pre% and port_post%
# For the purpose of this simple port, no pre or post steps needed.

.PHONY : port_prebuild port_postbuild port_prerun port_postrun port_preload port_postload
port_pre% port_post% : 

# FLAG : OPATH
# Path to the output folder. Default - current folder.
MKDIR = mkdir -p

