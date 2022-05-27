# Import Design
set DESIGN "SW"

read_file -format verilog  "$DESIGN.v"
current_design [get_designs $DESIGN]
link

source -echo -verbose ./synthesis.tcl
check_design


#set high_fanout_net_threshold 0
# Compile Design
current_design [get_designs ${DESIGN}]

uniquify
set_fix_multiple_port_nets -all -buffer_constants [get_designs *]

set_host_options -max_cores 16
compile
#compile_ultra
#compile_ultra
#compile_ultra -increment
#compile_ultra -increment
#optimize_netlist -area
#optimize_netlist -area

current_design [get_designs ${DESIGN}]

remove_unconnected_ports -blast_buses [get_cells -hierarchical *]

set bus_inference_style {%s[%d]}
set bus_naming_style {%s[%d]}
set hdlout_internal_busses true
change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _} -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]} -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule


# Report Output
current_design [get_designs ${DESIGN}]
#report_timing > "./Report/${DESIGN}_syn.timing"
report_area -nosplit -hierarchy > "./Report/${DESIGN}_syn.area"

# Output Design
current_design [get_designs ${DESIGN}]

remove_unconnected_ports -blast_buses [get_cells -hierarchical *]
set verilogout_higher_designs_first true
write -format ddc     -hierarchy -output "./Netlist/${DESIGN}_syn.ddc"
write -format verilog -hierarchy -output "./Netlist/${DESIGN}_syn.v"
write_sdf -version 1.0  -context verilog -load_delay cell ./Netlist/${DESIGN}_syn.sdf
write_sdc  ./Netlist/${DESIGN}_syn.sdc -version 1.8

report_area > area.log
report_timing > timing.log
report_qor   >  DT_syn.qor


exit
