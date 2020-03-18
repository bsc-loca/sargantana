#!/bin/bash
#This script will lint all the verilog and sv files with verilator
#An artifact with the errors is generated
artifact="/tmp/artifact_lint.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
#TODO: this script only works if used from the top directory
TOP="./"
#variables spyglass
FN="top_drac.sv"
N="top_drac"
EX="*.sv"
DIR="spyglass_reports"

##### Gather files and directories
#find paths of directories that are called rtl and save them in the format of
#verilator. path -I"other_paths"
include_dirs=""
while read file; do
    include_dirs="$include_dirs -I$file/"
done < <(find $TOP -depth -name "includes" -o -name "rtl")


#find rtl files and run linting in each one of them. Formated one file per line
#Exclude tb files and wip
rtl_files=""
while read file; do
    rtl_files=$rtl_files$file$'\n'
done < <(find $TOP \( ! -iname \tb_* -a ! -iname \wip_* -a ! -iname \*_pkg\* -a ! -path \*/tb* \) -and \( -iname \*.v -o -iname \*.vh -o -iname \*.sv \))
#remove the last character, If not verilator will try to run without file name
rtl_files=${rtl_files::-1}
echo "Spyglass"
echo "-----------------"
rm $artifact
while read p; do
  #include all the founded rtl folders as includes in case you have dependences 
  #grep for warnings and errors and save it on a variable. Notice that sterr is 
  #required
  echo -e "$GREEN $p $NC"
  #(/home/bscuser/programs/scripts/runLintSV.sh   includes/riscv_pkg.sv includes/drac_pkg.sv "$p"| grep 'warning\|error')2>&1 | tee -a $artifact 
done <<< "$rtl_files"

##### spyglass
rm /tmp/optionsspy
rm /tmp/importspy
#copy files and set script
	echo "read_file -type verilog {"includes/riscv_pkg.sv"}" >> /tmp/importspy 
	echo "read_file -type verilog {"includes/drac_pkg.sv"}" >> /tmp/importspy 
while read p; do
  #include all the founded rtl folders as includes in case you have dependences 
  #grep for warnings and errors and save it on a variable. Notice that sterr is 
  #required
	echo "read_file -type verilog {"$p"}" >> /tmp/importspy 
done <<< "$rtl_files"
#set the top for spyglass. must be the first argument of the script.
echo "set_option top top_drac" >> /tmp/optionsspy 
#remove old files and make local files
rm -rf $DIR 
mkdir $DIR
echo '
#!SPYGLASS_PROJECT_FILE
#!VERSION 3.0
#  -------------------------------------------------------------------
#  This is a software generated project file. Manual edits to this file could be lost during the next save operation
#  Copyright Synopsys Inc.
#  Last Updated By: SpyGlass SpyGlass_vO-2018.09-SP1-1
#
#  -------------------------------------------------------------------

##Data Import Section
#read_file -type verilog Vector_Accelerator/rtl/FIFO.sv
##Common Options Section

#set_option incdir { Vector_Accelerator/rtl/include }
set_option projectwdir .
set_option language_mode mixed
set_option designread_enable_synthesis no
set_option designread_disable_flatten no
#set_option enableSV yes
set_option enableSV09 yes
#set_option top inst_multi_lane_wrapper
set_option active_methodology $SPYGLASS_HOME/GuideWare/latest/block/rtl_handoff
set_option incdir { ./}
set_option handlememory

##Goal Setup Section
define_goal my_lint -policy {lint} {set_parameter fullpolicy yes} 
'> ./$DIR/$N.prj


#cp /home/drac/guillem/template_spyglass.prj ./$DIR/$N.prj
sed -i '/Data Import Section/ r /tmp/importspy' ./$DIR/$N.prj
sed -i '/Common Options Section/ r /tmp/optionsspy' ./$DIR/$N.prj
export SKIP_PLATFORM_CHECK=TRUE
export LM_LICENSE_FILE=27020@84.88.187.145
export SNPS_LICENSE_FILE=27020@epi01.bsc.es
export SNPSLMD_LICENSE_FILE=27020@epi01.bsc.es

#TODO: this may not work in all runners. Tested on EPI03
source /eda/synopsys/2018-19/scripts/SPYGLASS_2018.09-SP1-1_RHELx86.sh
export PATH=$PATH:'/home/drac/synopsys/install/spyglass/SPYGLASS2018.09-SP1-1/SPYGLASS_HOME/bin/'
echo -e "exports\n"
echo -e "run_goal lint/lint_rtl\nexit -save\n"| spyglass_main -shell -project $DIR/$N.prj
echo -e "remove\n"
mv top_drac $DIR
#check if the log has no errors
tmp=$(grep -r -i "Reported Messages:         0 Fatals,   0 Errors,     0 Warnings," ./spyglass_reports/top_drac/consolidated_reports/top_drac_lint_lint_rtl/spyglass.log)
#check if we have find "Reported Messages:         0 Fatals,   0 Errors,     0 Warnings"
! [ -s $tmp ]
rval="$?"
#if empty rval
if [ "$rval" -ne "0" ]; then
  	echo -e "$RED"
	grep -r -i "Reported Messages:" ./$DIR/$N/consolidated_reports/top_drac_lint_lint_rtl/spyglass.log
  	echo -e "$NC"
	exit $rval
fi
exit $rval
#Display actual results
