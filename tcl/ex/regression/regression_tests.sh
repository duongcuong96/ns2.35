#! /bin/bash

cd ..
# SFD test
set -v
set -x
../../ns cell-link.tcl -bottleneck_qdisc SFD -num_tcp 100  -num_udp 0 -duration 100 -ensemble_scheduler fcfs -congestion_control cubic  -headroom 0.0 -link_trace regression/1to100mbps.trace > /dev/null 2> /dev/null
set +v
set +x
python ../../utils/parse-trace.py cell-link.tr 100 0.95 > /dev/null 2> test.output
diff test.output regression/sfd-tcp100-1to100mbps.output
echo "Result of test is $?"

# CoDel test
set -v
set -x
../../ns cell-link.tcl -bottleneck_qdisc CoDel -num_tcp 100  -num_udp 0 -duration 100 -ensemble_scheduler pf -cdma_ewma_slots 100 -congestion_control cubic -headroom 0.0 -link_trace regression/1to100mbps.trace > /dev/null 2> /dev/null
set +v
set +x
python ../../utils/parse-trace.py cell-link.tr 100 0.95 > /dev/null 2> test.output
diff test.output regression/codel-tcp100-1to100mbps.output
echo "Result of test is $?"

# SFD on 100ms coherence time Verizon 4G trace.
set -v
set -x
../../ns cell-link.tcl -bottleneck_qdisc SFD -num_tcp 1  -num_udp 0 -duration 100 -ensemble_scheduler fcfs -congestion_control cubic -headroom 0.0 -link_trace regression/v4g.rates > /dev/null 2> /dev/null
set +v
set +x
python ../../utils/parse-trace.py cell-link.tr 100 0.95 > /dev/null 2> test.output
diff test.output regression/sfd-tcp1-v4grates.output
echo "Result of test is $?"

# CoDel on 100ms coherence time Verizon 4G trace.
set -v
set -x
../../ns cell-link.tcl -bottleneck_qdisc CoDel -num_tcp 1  -num_udp 0 -duration 100 -ensemble_scheduler pf -cdma_ewma_slots 100 -congestion_control cubic  -headroom 0.0 -link_trace regression/v4g.rates > /dev/null 2> /dev/null
set +v
set +x
python ../../utils/parse-trace.py cell-link.tr 100 0.95  > /dev/null 2> test.output
diff test.output regression/codel-tcp1-v4grates.output
echo "Result of test is $?"

cd -
