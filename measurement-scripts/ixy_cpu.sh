#!/bin/bash

# ADJUST PCIE ADDRESSES OR THIS WILL CRASH YOUR SYSTEM
export PCIE_IN="0000:03:00.0"
export PCIE_OUT="0000:03:00.1"

# specify directories for ixy and measurement results
export IXY_DIR="/root/ixy.rs"
export RESULTS_DIR="/root/results"

if [[ -d $RESULTS_DIR ]] ; then 
	echo "Result directory: $RESULTS_DIR"
else
	mkdir "$RESULTS_DIR"
	echo "Result directory: $RESULTS_DIR"
fi	

if [[ $1 == "--perf-stat" ]] ; then
	echo "enabling perf stat"
	PERF_STAT=1
else
	echo "run with --perf-stat to enble perf stat"
fi

cd $IXY_DIR

# Specify CPU frequencies for your measurement (in %)
# Consider that available frequencies depend on your hardware
for CPU in 49 52 55 61 64 67 70 73 79 82 85 88 94 97 100 
do
	echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
	echo $CPU > /sys/devices/system/cpu/intel_pstate/min_perf_pct 
	echo $CPU > /sys/devices/system/cpu/intel_pstate/max_perf_pct
	echo -n "Set CPU freq to (% of spec rate):" 
	cat /sys/devices/system/cpu/intel_pstate/max_perf_pct

	taskset -c 1 ./target/release/examples/forwarder $PCIE_IN $PCIE_OUT > "$RESULTS_DIR/ixy-cpu_$CPU.txt" &
		
	if [[ $PERF_STAT == 1 ]] ; then
		sleep 5
		perf stat -d --pid $(pidof forwarder) -o "$RESULTS_DIR/perf-stat-cpu_$CPU.txt"  &
	fi
		
	sleep 10
		
	if [[ $PERF_STAT == 1 ]] ; then
		kill -s 2 $(pidof perf_4.9)
		sleep 1
	fi

	kill $(pidof forwarder)
done
