#!/bin/bash
#This script will lint all the verilog and sv files with verilator
#An artifact with the errors is generated
artifact="/tmp/artifact_lint.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
#NOTE: this script only works if used from the top directory
TOP="./"
#variables spyglass
FN="top_drac.sv"
N="top_drac"
EX="*.sv"
DIR="spyglass_reports"

echo "Spyglass"
echo "-----------------"
rm -rf $DIR 
mkdir $DIR



#cp /home/drac/guillem/template_spyglass.prj ./$DIR/$N.prj
#sed -i '/Data Import Section/ r /tmp/importspy' ./$DIR/$N.prj
#sed -i '/Common Options Section/ r /tmp/optionsspy' ./$DIR/$N.prj
export SKIP_PLATFORM_CHECK=TRUE
export LM_LICENSE_FILE=27020@84.88.187.145
export SNPS_LICENSE_FILE=27020@epi01.bsc.es
export SNPSLMD_LICENSE_FILE=27020@epi01.bsc.es

source /eda/synopsys/2021-22/scripts/SPYGLASS_2021.09-SP1_RHELx86.sh
export PATH=$PATH:'/eda/synopsys/2021-22/RHELx86/SPYGLASS_2021.09-SP1/SPYGLASS_HOME/bin'

sg_shell -tcl_file_continue_on_error -tcl ./scripts/run_lint_rtl.tcl

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

