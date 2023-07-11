################################################################################
# Add files to project                                                         #
################################################################################

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Add files
set fileset_obj [get_filesets sources_1]
set files_to_add [list ]

set fp [open "${g_accel_dir}/filelist.f" r]
while {[gets $fp line] >= 0} {
    lappend files_to_add ${g_accel_dir}/$line
}
close $fp

set fp [open "${g_accel_dir}/fpga/common/filelist.f" r]
while {[gets $fp line] >= 0} {
    lappend files_to_add ${g_accel_dir}/$line
}
close $fp

lappend files_to_add ${g_accel_dir}/fpga/meep_shell/src/defines.svh
lappend files_to_add ${g_accel_dir}/fpga/meep_shell/src/sargantana_wrapper.sv

add_files -norecurse -fileset $fileset_obj $files_to_add

################################################################################
# Configure include directories                                                #
################################################################################

# Mark include directories
set include_paths {}
lappend include_paths "${g_accel_dir}/includes"
lappend include_paths "${g_accel_dir}/rtl"
lappend include_paths "${g_accel_dir}/fpga/meep_shell/src"
lappend include_paths "${g_accel_dir}/fpga/common/rtl/axi/include"
lappend include_paths "${g_accel_dir}/fpga/common/rtl/common_cells/include"
set_property include_dirs $include_paths $fileset_obj

# Mark directories with global verilog defines
set verilog_defines {}
lappend verilog_defines "${g_accel_dir}/fpga/meep_shell/src/defines.svh"
lappend verilog_defines "${g_accel_dir}/fpga/common/rtl/axi/include/axi/assign.svh"
lappend verilog_defines "${g_accel_dir}/fpga/common/rtl/axi/include/axi/typedef.svh"
lappend verilog_defines "${g_accel_dir}/fpga/common/rtl/common_cells/include/common_cells/registers.svh"
lappend verilog_defines "${g_accel_dir}/fpga/common/rtl/common_cells/include/common_cells/assertions.svh"
set_property verilog_define $verilog_defines $fileset_obj

# Mark files with global verilog defines
set file_obj [get_files -of_objects $fileset_obj [list "${g_accel_dir}/fpga/meep_shell/src/defines.svh"]]
set_property "is_global_include" "1" $file_obj
set file_obj [get_files -of_objects $fileset_obj [list "${g_accel_dir}/fpga/common/rtl/axi/include/axi/assign.svh"]]
set_property "is_global_include" "1" $file_obj
set file_obj [get_files -of_objects $fileset_obj [list "${g_accel_dir}/fpga/common/rtl/axi/include/axi/typedef.svh"]]
set_property "is_global_include" "1" $file_obj
set file_obj [get_files -of_objects $fileset_obj [list "${g_accel_dir}/fpga/common/rtl/common_cells/include/common_cells/registers.svh"]]
set_property "is_global_include" "1" $file_obj
set file_obj [get_files -of_objects $fileset_obj [list "${g_accel_dir}/fpga/common/rtl/common_cells/include/common_cells/assertions.svh"]]
set_property "is_global_include" "1" $file_obj