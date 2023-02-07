include ../../sim_common/Makefile.include

XLEN = 32
ROOTDIR = $(CURDIR)/../../fw/riscv-arch-test
TARGETDIR = $(ROOTDIR)/riscv-target
RISCV_TARGET = mycore
RISCV_DEVICE = m
RVTEST_DEFINES = -march=rv32i_m -mabi=ilp32

include $(ROOTDIR)/riscv-test-suite/Makefile.include

test_%: $(work_dir_isa)/%.vh obj_dir/Vtop
	@echo "-------- Start $@ --------"
	cp $< fw.vh
	obj_dir/Vtop $(SIM_ARGS) +TEST_FW=fw.vh && ([ $$? -eq 0 ] && echo "$@ success!") || (echo "$@ failure!" && rm -rf obj_dir && gtkwave -a ../top.gtkw -6 -7 $(GTK_FLAGS) logs_top/wave.fst && exit 1)
	mv logs_top/wave.fst $@.fst
	rm -rf logs_top fw.vh
	@echo "--------------------------"

tests_ls = $(addprefix test_,$(tests_name))

tests: $(tests_ls)
	rm -rf obj_dir
