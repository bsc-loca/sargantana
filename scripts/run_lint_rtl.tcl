set project spyglass_reports/top_drac
new_project ${project}
current_methodology $env(SPYGLASS_HOME)/GuideWare/latest/block/rtl_handoff

##Data Import Section
read_file -type sourcelist ./filelist.f
##Common Options Section
set_option top top_drac
set_option incdir {"./rtl"}
read_file -type awl ./scripts/waiver.awl

set_option language_mode mixed
set_option designread_enable_synthesis no
set_option designread_disable_flatten no
# for bigger modules synthesis
set_option mthresh 100000


set_option enableSV09 yes

set_option incdir { ./}
set_option handlememory
set_parameter handle_large_bus yes

##Goal Setup Section
define_goal my_lint -policy {lint} {set_parameter fullpolicy yes} 

exports

run_goal lint/lint_rtl

exit -save



