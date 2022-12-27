ifneq ($(words $(CURDIR)),1)
 $(error Unsupported: GNU Make cannot build in directories containing spaces, build elsewhere: '$(CURDIR)')
endif

VERILATOR = verilator
VERILATOR_COVERAGE = verilator_coverage

# Generate C++ in executable form
VERILATOR_FLAGS += -cc --exe -j 6
# Generate makefile dependencies (not shown as complicates the Makefile)
#VERILATOR_FLAGS += -MMD
# Optimize
VERILATOR_FLAGS += -x-assign fast
# Warn abount lint issues; may not want this on less solid designs
VERILATOR_FLAGS += -Wall
# Make waveforms
VERILATOR_FLAGS += --trace-fst --trace-structs
# Check SystemVerilog assertions
VERILATOR_FLAGS += --assert
# Generate coverage analysis
VERILATOR_FLAGS += --coverage
# Run Verilator in debug mode
#VERILATOR_FLAGS += --debug
# Add this trace to get a backtrace in gdb
#VERILATOR_FLAGS += --gdbbt 
VERILATOR_FLAGS += --build --hierarchical
VERILATOR_FLAGS += -CFLAGS "-I../../vrf/tb/ -DTOP_NAME=$*" -DTO_SIM

VERILATOR_INPUT = -f input.vc ../../vrf/$*.sv ../../vrf/tb/tb.cpp ../../vrf/tb/tb_$*.cpp

TESTS_LIST = 

SIM_ARGS =
ifneq ($(cycles),)
SIM_ARGS += +cycles=$(cycles)
endif
ifneq ($(trace),)
SIM_ARGS += +trace
endif

default: top
#default: $(TESTS_LIST)

XLEN = 32
ROOTDIR = $(CURDIR)/../fw/riscv-arch-test
TARGETDIR = $(ROOTDIR)/riscv-target
RISCV_TARGET = mycore
RISCV_DEVICE = i
RVTEST_DEFINES = -march=rv32i -mabi=ilp32

include $(ROOTDIR)/riscv-test-suite/Makefile.include

obj_dir/V%:
	@rm -rf logs_$* obj_dir
	@$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_INPUT)

rv%:
	@echo "--- Prepare test $@ ---"
	@rm -rf logs_$@ obj_dir
	$(VERILATOR) $(VERILATOR_FLAGS) -CFLAGS "-I../tb/ -DTOP_NAME=$@" -DTO_SIM -f input.vc $@.sv tb/tb.cpp tb_$@.cpp
	@mkdir -p logs_$@
	@echo "--- Run test $@ ---"
	@obj_dir/V$@ +trace || (exit 1)
	@rm -rf obj_dir
	@echo "--- Test $@ finished ---"
	gtkwave -a $@.gtkw -6 -7 logs_$@/wave.fst

top: obj_dir/Vtop
	@echo "--- Test $@ running ---"
	obj_dir/Vtop $(SIM_ARGS)
ifneq ($(trace),)
	@mv logs_top/wave.fst $@.fst
endif
	@rm -rf logs_top obj_dir fw.vh
	@echo "--- Test $@ finished ---"
ifneq ($(trace),)
	@gtkwave -a top.gtkw -6 -7 $@.fst
endif

test_%: $(work_dir_isa)/%.vh obj_dir/Vtop
	@cp $< fw.vh
	@obj_dir/Vtop $(SIM_ARGS) +TEST_FW=fw.vh && ([ $$? -eq 0 ] && echo "$@ success!") || (echo "$@ failure!" && gtkwave -a top.gtkw -6 -7 logs_top/wave.fst && exit 1)
	@mv logs_top/wave.fst $@.fst
	@rm -rf logs_top fw.vh

tests_ls = $(addprefix test_,$(tests_name))

tests: $(tests_ls)
	@rm -rf obj_dir

show-config:
	$(VERILATOR) -V

all: top

maintainer-copy::
clean mostlyclean distclean maintainer-clean:: clean_test
	-rm -rf obj_dir logs *.log *.dmp *.vpd coverage.dat core
