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
for CPU in 100 #49 100
do
	echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
	echo $CPU > /sys/devices/system/cpu/intel_pstate/min_perf_pct 
	echo $CPU > /sys/devices/system/cpu/intel_pstate/max_perf_pct
	echo -n "Set CPU freq to (% of spec rate):" 
	cat /sys/devices/system/cpu/intel_pstate/max_perf_pct

	# Specify considered batch sizes (Default is 32)	
	for BATCH in 1 2 4 8 16 32 64 128 256
	do
		sed -i "s/BATCH_SIZE: usize =.*/BATCH_SIZE: usize = $BATCH;/g" examples/forwarder.rs
		cargo build --release --all-targets
		taskset -c 1 ./target/release/examples/forwarder $PCIE_IN $PCIE_OUT > "$RESULTS_DIR/ixy-cpu_$CPU-batch_$BATCH.txt" &
		
		if [[ $PERF_STAT == 1 ]] ; then
			sleep 5
			perf stat -d --pid $(pidof forwarder) -x" " -o "$RESULTS_DIR/perf-stat-cpu_$CPU-batch_$BATCH.txt"  &
		fi
		
		sleep 10
		
		if [[ $PERF_STAT == 1 ]] ; then
			kill -s 2 $(pidof perf_4.9)
			sleep 1
		fi

		kill $(pidof forwarder)
	done
done

# Reset ixy 
sed -i "s/BATCH_SIZE: usize =.*/BATCH_SIZE: usize = 32;/g" examples/forwarder.rs
cargo build --release --all-targets
