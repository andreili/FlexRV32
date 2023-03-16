XLEN = 32
ROOTDIR = $(CURDIR)/../../fw/riscv-arch-test
TARGETDIR = $(ROOTDIR)/riscv-target
RISCV_TARGET = mycore
RISCV_DEVICE = i
RVTEST_DEFINES = -march=rv32i -mabi=ilp32

include $(ROOTDIR)/riscv-test-suite/Makefile.include
include ../../sim_common/Makefile.include

tests_ls = $(addprefix test_,$(tests_name))

tests: $(tests_ls)
	rm -rf obj_dir
