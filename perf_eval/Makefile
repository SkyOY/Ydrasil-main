SHELL := /usr/bin/env bash

.PHONY: all sim rvtests coremark report vivado clean smoke

all:
	./scripts/run_all.sh

sim:
	./scripts/build_sim.sh

rvtests: sim
	./scripts/run_rvtests.sh

coremark: sim
	./scripts/run_coremark.sh

report:
	./scripts/parse_results.py

vivado:
	./scripts/run_vivado_fmax.sh

smoke: sim
	RVTEST_LIST=rv32ui:add ./scripts/run_rvtests.sh
	./scripts/parse_results.py

clean:
	rm -rf build out vivado/work vivado/reports vivado/vivado_command.txt
