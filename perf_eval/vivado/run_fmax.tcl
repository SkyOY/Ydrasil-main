# Vivado batch timing sweep for Ydrasil.
# Args: <repo_root_win> <eval_root_win> <freq_list>

set repo_root [lindex $argv 0]
set eval_root [lindex $argv 1]
set freq_list [split [lindex $argv 2] " "]

set reports_dir [file join $eval_root vivado reports]
set work_dir [file join $eval_root vivado work]
file mkdir $reports_dir
file delete -force $work_dir
file mkdir $work_dir

set src_project [file join $repo_root FPGA Ydrasil_FPGA.xpr]
set copied_project [file join $work_dir Ydrasil_FPGA.xpr]

open_project $src_project
save_project_as Ydrasil_FPGA $work_dir -force
close_project
open_project $copied_project

set results {}

proc first_slack {kind} {
    if {$kind eq "setup"} {
        set paths [get_timing_paths -setup -max_paths 1 -quiet]
    } else {
        set paths [get_timing_paths -hold -max_paths 1 -quiet]
    }
    if {[llength $paths] == 0} {
        return 0.0
    }
    return [get_property SLACK [lindex $paths 0]]
}

foreach freq $freq_list {
    puts "INFO: Running Fmax point ${freq} MHz"
    set pll [get_ips -quiet pll]
    if {[llength $pll] > 0} {
        set_property CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $freq $pll
        generate_target all $pll
    }

    reset_run synth_1
    launch_runs synth_1 -jobs 16
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        lappend results [dict create freq_mhz $freq status synth_failed]
        continue
    }

    reset_run impl_1
    launch_runs impl_1 -to_step route_design -jobs 16
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        lappend results [dict create freq_mhz $freq status impl_failed]
        continue
    }

    open_run impl_1
    report_timing_summary -file [file join $reports_dir timing_${freq}.rpt]
    report_utilization -file [file join $reports_dir utilization_${freq}.rpt]

    set wns [first_slack setup]
    set whs [first_slack hold]
    set status [expr {($wns >= 0.0 && $whs >= 0.0) ? "pass" : "fail"}]
    lappend results [dict create freq_mhz $freq status $status wns $wns whs $whs]
}

set json_file [open [file join $reports_dir fmax_results.json] w]
puts $json_file "{"
puts $json_file "  \"status\": \"completed\","
puts $json_file "  \"points\": ["
for {set i 0} {$i < [llength $results]} {incr i} {
    set r [lindex $results $i]
    set comma [expr {$i == [llength $results] - 1 ? "" : ","}]
    puts -nonewline $json_file "    {"
    set first 1
    foreach {k v} $r {
        if {!$first} { puts -nonewline $json_file ", " }
        set first 0
        if {[string is double -strict $v]} {
            puts -nonewline $json_file "\"$k\": $v"
        } else {
            puts -nonewline $json_file "\"$k\": \"$v\""
        }
    }
    puts $json_file "}$comma"
}
puts $json_file "  ]"
puts $json_file "}"
close $json_file

close_project
