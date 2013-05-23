# Author : Hari Balakrishnan
# Class that simulates random on/off traffic, where
# on and off durations are drawn from a specific distribution.
source timer.tcl

Class LoggingApp -superclass {Application Timer}

LoggingApp instproc init {id} {
    $self instvar srcid_ nbytes_ cumrtt_ numsamples_ u_ offtotal_ on_ranvar_ off_ranvar_ rtt_samples_ flowfile
    global opt
    $self set srcid_ $id
    $self reset
    $self set u_ [new RandomVariable/Uniform]
    $self set offtotal_ 0.0
    
    # Internet flow CDF distribution
    $self set flowfile flowcdf-allman-icsi.tcl

    # Create exponential on/off RandomVariables
    $self set on_ranvar_  [new RandomVariable/$opt(onrand)]
    $self set off_ranvar_ [new RandomVariable/$opt(offrand)]
    if { $opt(ontype) == "time" } {
        $on_ranvar_ set avg_ $opt(onavg)
    } elseif { $opt(ontype) == "bytes" } {
            $on_ranvar_ set avg_ $opt(avgbytes)
    } elseif { $opt(ontype) == "flowcdf" } {
        source $flowfile
    }
    set off_ranvar_ [new RandomVariable/$opt(offrand)]
    $off_ranvar_ set avg_ $opt(offavg)

    $self settype
    $self next
}

LoggingApp instproc reset { } {
    $self instvar nbytes_ cumrtt_ numsamples_ state_

    $self set state_ OFF
    $self set nbytes_ 0
    $self set cumrtt_ 0.0
    $self set numsamples_ 0
    $self set rtt_samples_ {}
}

LoggingApp instproc settype { } {
    $self instvar endtime_ maxbytes_ 
    global opt
    if { $opt(ontype) == "time" } {
        $self set maxbytes_ "infinity"; # not byte-limited
        $self set endtime_ 0
    } elseif { ($opt(ontype) == "bytes") || ($opt(ontype) == "flowcdf") } {
        $self set endtime_ [expr $opt(simtime) + 1]
        $self set maxbytes_ 0
    } elseif { $opt(ontype) == "longrunning" } {
        $self set maxbytes_ "infinity"
        $self set endtime_ [expr $opt(simtime) + 1]
    } else {
        puts "Invalid ontype"
        exit 5
    }
}

# called at the start of the simulation for the first run
LoggingApp instproc go { starttime } {
    $self instvar maxbytes_ endtime_ laststart_ srcid_ state_ u_ on_ranvar_
    global ns opt src flowcdf

    set laststart_ $starttime
    if { $starttime <= [$ns now] } {
        # current time is equal to (or more than) starttime, so let's start
        set state_ ON
        if { $opt(ontype) == "bytes" } {
            set maxbytes_ [$on_ranvar_ value]; # in bytes
        } elseif  { $opt(ontype) == "time" } {
            set endtime_ [$on_ranvar_ value]; # in time
        } elseif  { $opt(ontype) == "flowcdf" } {
            $u_ set min_ 0.0
            $u_ set max_ 1.0
            set r [$u_ value]
            set idx [expr int(100000*$r)]
            if { $idx > [llength $flowcdf] } {
                set idx [expr [llength $flowcdf] - 1]
            }
            set maxbytes_ [expr 40 + [lindex $flowcdf $idx]]
#            puts "Flow len $maxbytes_"
        } elseif { $opt(ontype) == "longrunning" } {
           set maxbytes_ "infinity"
           set endtime_ $opt(simtime)
        }

        puts "$starttime: Turning on $srcid_ for $maxbytes_ bytes duration $endtime_"

        $ns at [$ns now] "$src($srcid_) start"
        # Start right away, because starttime was less than or equal to current time
    } else {
        # Not yet time to start, so schedule an alarm to wake up at $starttime
        $self sched [expr $starttime - [$ns now]]
    }
}

LoggingApp instproc timeout {} {
    $self instvar srcid_ maxbytes_ endtime_
    global ns src

    # retry the go method now, it should be time to start
    $self go [$ns now]
}

# LoggingApp maintains information for each on-off period; when turned off, recv calls StatCollector::update,
# which maintains the cumulative statistics for the srcid (i.e., src-dest pair) across all on-off periods.
LoggingApp instproc recv { bytes } {
    # there's one of these objects for each src/dest pair 
    $self instvar nbytes_ srcid_ cumrtt_ numsamples_ maxbytes_ endtime_ laststart_ state_ u_ offtotal_ off_ranvar_ on_ranvar_ rtt_samples_
    global ns opt src tp stats flowcdf

    if { [string equal $state_ "OFF"] } {
        puts "Time [$ns now] src $srcid_ Ignoring last few packet receptions from previous epoch"
        return
    }

    assert [expr $bytes > 0 ]
    set nbytes_ [expr $nbytes_ + $bytes]
    set tcp_sender [lindex $tp($srcid_) 0]
    set rtt_ [expr [$tcp_sender set rtt_] * [$tcp_sender set tcpTick_]]
    if {$rtt_ > 0.0} {
        set cumrtt_ [expr $rtt_  + $cumrtt_]
        lappend rtt_samples_ $rtt_
        set numsamples_ [expr $numsamples_ + 1]
    }

    set ontime [expr [$ns now] - $laststart_]
    if { $nbytes_ >= $maxbytes_ || $ontime >= $endtime_ || $opt(simtime) < [$ns now]} {
        puts "[$ns now]: Turning off $srcid_ ontime $ontime"
        $ns at [$ns now] "$src($srcid_) stop"
        $stats($srcid_) update $nbytes_ $ontime $cumrtt_ $numsamples_ $rtt_samples_
        $self reset
        set nexttime [expr [$ns now] + [$off_ranvar_ value]]; # stay off until nexttime
        set offtotal_ [expr $offtotal_ + $nexttime - [$ns now]]
#        puts "OFFTOTAL for src $srcid_ $offtotal_"
        set laststart_ $nexttime
        if { $nexttime < $opt(simtime) } { 
            # set up for next on period
            $self sched [expr $nexttime - [$ns now]]
#            $ns at $nexttime: "$src($srcid_) start"; # schedule next start
#            puts "@$nexttime: Turning on $srcid_ for $maxbytes_ bytes $endtime_ s"
        }
    }
    return nbytes_
}

LoggingApp instproc sample_off_duration {} {
    $self instvar off_ranvar_
    return [$off_ranvar_ value]
}