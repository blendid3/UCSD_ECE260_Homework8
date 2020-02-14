set design jpeg_encoder

if {![file exists icc2_report]} {
	exec mkdir icc2_report
}

if {[file exists $design]} {
	exec chmod -R 777 $design
	exec rm -r $design
}

# read lib
set home "/home/linux/ieng6/ee260bwi20/public/data/libraries"
set search_path ". $home"
set target_library "$home/db/tcbn65gpluswc.db"
set link_library "* $target_library"
set techfile "$home/techfiles/tsmcn65_8lmT2.tf"
set tech_info "{M1 vertical 0.0} {M2 horizontal 0.0} {M3 vertical 0.0} {M4 horizontal 0.0} {M5 vertical 0.0} {M6 horizontal 0.0} {M7 vertical 0.0} {M8 horizontal 0.0} {CB vertical 0.0}"
set ndm "./ndm/tsmc65.ndm"

set tlup "$home/techfiles/cln65g+_1p08m+alrdl_top2_cworst.tluplus"
set tech2itf_map "$home/techfiles/star.map_8M"

create_lib $design -tech $techfile -ref_libs $ndm

read_verilog -top $design "../../gate/$design\.v"
current_block $design
link_block
save_lib

load_upf ${design}.upf
commit_upf
set_voltage 0.90 -object_list [get_supply_nets VDD]
set_voltage 0.00 -object_list [get_supply_nets VSS]
connect_pg_net -automatic 
read_parasitic_tech -tlup $tlup -layermap $tech2itf_map -name wst

#scenario
remove_modes -all; remove_corners -all; remove_scenarios -all
set s "WC"
create_mode $s
create_corner $s
create_scenario -name $s -mode $s -corner $s
current_scenario $s
source "../../gate/$design\.sdc"
set_scenario_status $s -none -setup true -hold true -leakage_power true -dynamic_power true -max_transition true -max_capacitance true -min_capacitance false -active true
set_parasitic_parameters -late_spec wst -early_spec wst

exec date > timer

# floorplan
foreach direction_offset_pair $tech_info {
	set layer [lindex $direction_offset_pair 0]
	set direction [lindex $direction_offset_pair 1]
	set offset [lindex $direction_offset_pair 2]
	set_attribute [get_layers $layer] routing_direction $direction
	if {$offset != ""} {
		set_attribute [get_layers $layer] track_offset $offset
	}
}

initialize_floorplan -core_utilization 0.6 -core_offset 10
place_pins -self 
save_block -as ${design}_floorplan.design
exec date >> timer

#power rail
create_pg_std_cell_conn_pattern m1_rail -layers {M1} -rail_width 0.33
set_pg_strategy rail_strategy -pattern {{name: m1_rail} {nets: VDD VSS}} -core
compile_pg -strategies rail_strategy

#placement
set_app_options -as -list { place.coarse.continue_on_missing_scandef true }

#place_opt
set_app_options -name place_opt.flow.enable_ccd -value true
set_app_options -name place_opt.flow.trial_clock_tree -value true
set_app_options -name place_opt.flow.optimize_icgs -value true
set_app_options -name place_opt.congestion.effort -value high

set_scenario_status -active true [all_scenarios]
set_voltage 0.90 -object_list [get_supply_nets VDD]
set_voltage 0.00 -object_list [get_supply_nets VSS]
place_opt

#check_legality -verbose

#report design
report_design -all > ./icc2_report/place_design.rpt
report_qor  > ./icc2_report/place_qor.rpt
report_power > ./icc2_report/place_power.rpt
save_block -as ${design}_place.design
exec date >> timer

#routing options
set_app_options -name clock_opt.flow.enable_ccd -value true
set_app_options -name clock_opt.flow.enable_clock_power_recovery -value area

set_app_options -name route.global.timing_driven -value true
set_app_options -name route.track.timing_driven -value true
set_app_options -name route.detail.timing_driven -value true

set_app_options -name time.si_enable_analysis -value true
set_app_options -name route.global.crosstalk_driven -value true
set_app_options -name route.track.crosstalk_driven -value true

set_app_options -name route_opt.flow.enable_ccd -value true
set_app_options -name route_opt.flow.enable_power -value true
set_app_options -name route_opt.flow.xtalk_reduction -value true

#cts
clock_opt -from build_clock -to final_opto

#report design
report_design -all > ./icc2_report/cts_design.rpt
report_qor  > ./icc2_report/cts_qor.rpt
report_power > ./icc2_report/cts_power.rpt
save_block -as ${design}_cts.design
exec date >> timer

#route
route_auto
route_opt 

#report design
report_design -all > ./icc2_report/route_design.rpt
report_qor  > ./icc2_report/route_qor.rpt
report_power > ./icc2_report/route_power.rpt
report_timing -nworst 1 -nosplit -nets > ./icc2_report/route_timing.rpt
save_block -as ${design}_route.design
exec date >> timer


write_parasitics -output ${design}.spef -format spef
write_def -version 5.7 icc_$design\.def
write_verilog icc_$design\_out.v

exit






create_mw_lib -tech "$home/techfiles/tsmcn65_8lmT2.tf" -bus_naming_style {[%d]} -mw_reference_library "$home/techfiles/tcbn65gplus" mwlib

open_mw_lib mwlib

# load design
import_designs "../../gate/$design\.v" -format verilog -top $design
read_sdc "../../gate/$design\.sdc"

# read techfiles
set_tlu_plus_files \
-max_tluplus "$home/techfiles/cln65g+_1p08m+alrdl_top2_cworst.tluplus" \
-min_tluplus "$home/techfiles/cln65g+_1p08m+alrdl_top2_cworst.tluplus" \
-tech2itf_map "$home/techfiles/star.map_8M"
check_tlu_plus_files

exec date > timer

# floorplan
create_floorplan \
-control_type "aspect_ratio" -core_aspect_ratio "1" \
-core_utilization "0.6" -row_core_ratio "1" \
-left_io2core "10" -bottom_io2core "10" -right_io2core "10" -top_io2core "10" \
-start_first_row

# placement 
create_fp_placement -effort high -timing_driven 
set_optimize_pre_cts_power_options -low_power_placement true
place_opt -effort high -congestion -power -area_recovery

# report design
report_power > ./icc_report/place_power.rpt
report_qor > ./icc_report/place_qor.rpt
report_design -physical > ./icc_report/place_phy.rpt
save_mw_cel -as $design\_placed

exec date >> timer

# CTS
set_route_mode_options -zroute true
set_si_options -route_xtalk_prevention true -delta_delay true
set_route_zrt_global_options -timing_driven true -crosstalk_driven true
set_route_zrt_track_options -timing_driven true -crosstalk_driven true
set_route_zrt_detail_options -timing_drive true
clock_opt -congestion -area_recovery -fix_hold_all_clocks -concurrent_clock_and_data -power

# report design
report_power > ./icc_report/CT_power.rpt
report_clock_tree > ./icc_report/CT.rpt
report_design -physical > ./icc_report/CT_phy.rpt
save_mw_cel -as $design\_CT

exec date >> timer

# route
route_opt -xtalk_reduction -power -area_recovery -effort high

# RC extraction
extract_rc -coupling_cap
write_parasitics -format SPEF -output  icc_$design\.spef
# DEF generation
write_def -version 5.7 -lef lef.ref -output icc_$design\.def

# report design
report_area >  ./icc_report/route_area.rpt
report_design -physical > ./icc_report/route_phy.rpt
report_qor  > ./icc_report/route_qor.rpt
report_power > ./icc_report/route_power.rpt
report_timing -nworst 1 -nosplit -nets > ./icc_report/route_timing.rpt

exec date >> timer

save_mw_cel -as $design\_routed
change_names -rules verilog -hierarchy
write_verilog icc_$design\_out.v
exit
