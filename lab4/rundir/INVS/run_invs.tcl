if {![file exists invs_report]} {
	exec mkdir invs_report
}

# Load design
set design jpeg_encoder
set netlist "../../gate/${design}.v"
set sdc "../../gate/${design}.sdc"
set home "/home/linux/ieng6/ee260bwi20/public/data/libraries"
set libworst "$home/lib/tcbn65gpluswc.lib"
set lef "$home/techfiles/tcbn65gplus_8lmT2.lef"
set captblworst "$home/techfiles/cln65g+_1p08m+alrdl_top2_cworst.captable"

# default settings
set init_pwr_net "vdd"
set init_gnd_net "gnd"

# default settings
set init_verilog "$netlist"
set init_design_netlisttype "Verilog"
set init_design_settop 1
set init_top_cell "$design"
set init_lef_file "$lef"

# MCMM setup
create_library_set -name WC_LIB -timing $libworst
create_library_set -name BC_LIB -timing $libworst
create_rc_corner -name Cmax -cap_table $captblworst -T 125
create_rc_corner -name Cmin -cap_table $captblworst -T -40
create_delay_corner -name WC -library_set WC_LIB -rc_corner Cmax
create_delay_corner -name BC -library_set BC_LIB -rc_corner Cmin
create_constraint_mode -name CON -sdc_file [list $sdc]
create_analysis_view -name WC_VIEW -delay_corner WC -constraint_mode CON
create_analysis_view -name BC_VIEW -delay_corner BC -constraint_mode CON
init_design -setup {WC_VIEW} -hold {BC_VIEW}

set_interactive_constraint_modes {CON}
setDesignMode -process 65
exec date > timer

# floorplan
floorPlan -site core -r 1 0.6 10.0 10.0 10.0 10.0

# placement
setOptMode -effort high -powerEffort high -leakageToDynamicRatio 0.5 -fixFanoutLoad true
place_opt_design
# report design
report_power -outfile ./invs_report/place_power.rpt
summaryReport -noHtml -outfile ./invs_report/place_summary.rpt
saveDesign $design\_placed.enc
exec date >> timer

# Clock tree synthesis 
set_ccopt_property -update_io_latency false
create_ccopt_clock_tree_spec
ccopt_design
set_propagated_clock [all_clocks]
optDesign -postCTS -hold
# report design
report_power -outfile ./invs_report/CT_power.rpt
getNetWireLength clk* -outFile ./invs_report/CT_WL.rpt
report_ccopt_clock_trees -file ./invs_report/CT.rpt
summaryReport -noHtml -outfile ./invs_report/CT_summary.rpt
saveDesign $design\_CT.enc
exec date >> timer

# Routing
setNanoRouteMode -quiet -drouteAllowMergedWireAtPin false
setNanoRouteMode -quiet -drouteFixAntenna true
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
setNanoRouteMode -quiet -routeSiEffort medium
setNanoRouteMode -quiet -routeWithSiPostRouteFix false
setNanoRouteMode -quiet -drouteAutoStop true
setNanoRouteMode -quiet -routeSelectedNetOnly false
setNanoRouteMode -quiet -drouteStartIteration default
routeDesign

# RC extraction for optimization
setExtractRCMode -engine postRoute
extractRC

# Post-route timing optimization
setAnalysisMode -analysisType onChipVariation -cppr both
optDesign -postRoute -setup -hold

# SPEF generation
extractRC
rcOut -spef invs_$design\.spef
# DEF generation
defOut -routing invs_$design\.def

# design report
summaryReport -noHtml -outfile ./invs_report/route_summary.rpt
report_power -outfile ./invs_report/route_power.rpt
report_timing > ./invs_report/route_timing.rpt

exec date >> timer

saveDesign $design\_routed.enc
saveNetlist invs_$design\.v
exit

