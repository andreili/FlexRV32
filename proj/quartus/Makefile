PROJECT = riscv_soc
REVISION = 0

QUARTUS_PATH = /opt/intelFPGA_lite/22.1std/quartus/bin/
QUARTUS_MAP  = $(QUARTUS_PATH)quartus_map
QUARTUS_FIT  = $(QUARTUS_PATH)quartus_fit
QUARTUS_ASM  = $(QUARTUS_PATH)quartus_asm
QUARTUS_STA  = $(QUARTUS_PATH)quartus_sta
QUARTUS_SH   = $(QUARTUS_PATH)quartus_sh
QUARTUS_PGM  = $(QUARTUS_PATH)quartus_pgm
QUARTUS_CDB  = $(QUARTUS_PATH)quartus_cdb

MSIM_PATH = /c/intelFPGA_lite/18.1/modelsim_ase/win32aloem/
MSI_MVSIM  = $(MSIM_PATH)vsim

FAMILY = "Cyclone IV E"
PART = ep4ce6f17c8
BOARDFILE = CycV_SoC_v1
SDC = SoC.sdc

PROJ_DIR = ./
RTL_DIR = ../../rtl

TEST_NAMES = test_dc
SIM_TARGETS := $(TEST_NAMES:%=%.vcd)

include ../../rtl/list/quartus.f

all: clean assignment ip_gen map fit asm sta
	$(info $(file < $(PROJECT).fit.summary))

assignment:
	$(info RTL: Generate Quartus project files)
	$(QUARTUS_SH) --64bit --prepare -f $(FAMILY) -t tb_top $(PROJECT) > /dev/null
	cat $(SDC) > $(PROJECT).sdc
	cat $(BOARDFILE) > $(PROJECT).qsf

ip_gen:
	$(info RTL: Generate IP cores)
	mkdir -p output_files
	$(QUARTUS_SH) --64bit -t ./scripts/ip_gen.tcl ./$(PROJECT).qpf $(REVISION) ./ip.json > ./output_files/msg_ip.txt
	rm -rf 0.qsf

map:
	$(info RTL: Analysis & Synthesis)
	$(QUARTUS_MAP) --64bit --read_settings_files=on $(addprefix --source=,$(SRCS)) $(PROJECT) > ./output_files/msg_map.txt

fit:
	$(info RTL: Fitter)
	$(QUARTUS_FIT) --64bit --part=$(PART) --read_settings_files=on $(PROJECT) > ./output_files/msg_fit.txt

asm:
	$(info RTL: Assembly)
	$(QUARTUS_ASM) --64bit $(PROJECT) > ./output_files/msg_asm.txt

sta:
	$(info RTL: Timing Analyze)
	$(QUARTUS_STA) --64bit $(PROJECT) > ./output_files/msg_sta.txt
#	$(QUARTUS_SH) --64bit --determine_smart_action $(PROJECT) > smart.log

update_mif:
	$(info RTL: Update MIF)
	$(QUARTUS_CDB) --64bit --read_settings_files=on --update_mif $(PROJECT) > /dev/null
	$(info RTL: Assembly)
	$(QUARTUS_ASM) --64bit $(PROJECT) > /dev/null

program: $(PROJECT).sof
	$(QUARTUS_PGM) $(PGM_ARGS) -o "P;$(PROJECT).sof"

clean:
	$(info RTL: Clean previous build artifacts)
	rm -rf ./db/ ./greybox_tmp/ ./incremental_db/ *.qpf *.qsf *.rpt
	rm -rf *.smsg *.summary *.sld *.sof $(PROJECT).sdc *.jdi *.pin *.qws *.chg
	rm -rf ./vrf output_files *.txt *.xml
	rm -rf ./ips/pll/*.bsf ./ips/pll/*.cmp ./ips/pll/*.ppf ./ips/pll/*.qip ./ips/pll/*.sip
	rm -rf ./ips/pll/*.spd ./ips/pll/*.spf ./ips/pll/*.f ./ips/pll/pll  ./ips/pll/pll_sim

sim: $(SIM_TARGETS)

%.vcd:
	$(info Run test $*)
	rm -rf ./vrf
	python ./scripts/sim_prepare.py $* ../../hw_fpga_mux_board/list/quartus.f $(RTL_DIR) $(PROJ_DIR)
	cd ./vrf/$* && $(MSI_MVSIM) -do sim.do > /dev/null
	cp ./vrf/$*/$@ ./vrf/$@

.PHONY: assignment clean all program sim
.SECONDARY:
$(V).SILENT:
