SHELL = /bin/bash

SIM_DIR = sim

VERILATOR = verilator

VERILATOR_OPTS = \
	-Wall \
	-Wno-WIDTH \
	-Wno-UNUSED \
	-Wno-BLKSEQ \
	--cc \
	+1364-2001ext+v \
	-Wno-fatal \
	--Mdir sim \
	--trace \

VERILATOR_MAKE_OPTS = OPT="-Wall -Wpedantic -Wno-narrowing -Wno-deprecated -O3 -DNDEBUG -std=gnu++14 -I ../../../ -DDNN_USE_IMAGE_API"

DESIGN_SRCS = \
tiny_dnn_top.sv \
tiny_dnn_control.sv \
tiny_dnn_buf.sv \
tiny_dnn_core.sv \

VERILATOR_CPP_TB = train.cpp

default: $(SIM_DIR)/Vtiny_dnn_top

sim: $(SIM_DIR)/Vtiny_dnn_top

$(SIM_DIR)/Vtiny_dnn_top: $(DESIGN_SRCS) $(VERILATOR_CPP_TB)
	$(VERILATOR) $(VERILATOR_OPTS) $(DESIGN_SRCS) --exe ../$(VERILATOR_CPP_TB)
	cd sim; make $(VERILATOR_MAKE_OPTS) -f Vtiny_dnn_top.mk Vtiny_dnn_top__ALL.a
	cd sim; make $(VERILATOR_MAKE_OPTS) -f Vtiny_dnn_top.mk Vtiny_dnn_top

clean:
	rm -rf sim/ tmp.vcd

.PHONY:
