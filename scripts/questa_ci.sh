#!/bin/bash
#runs all the questa TB and reports PASS or FAIL messages
#Testbench require to finish with $finish; to be non interactive
#An artifact with the errors is generated
artifact="/tmp/artifact_questa.log"
RED='\033[0;31m'         
GREEN='\033[0;32m'       
NC='\033[0m' # No Color  
TOP=$PWD

# A failed `cd` leaves the shell in the previous testbench directory, so the next
# runtest.sh re-runs the test that already passed and its output is logged under
# this step's name. Report the step as missing and keep going, then exit nonzero.
missing=0
run_tb() {
    local dir="$1" label="$2"
    echo "*** results of file: $label" 2>&1 | tee -a $artifact
    if cd "$TOP/$dir" 2>/dev/null; then
        (./runtest.sh -c ) 2>&1 | tee -a $artifact
    else
        echo "MISSING TESTBENCH DIRECTORY: $dir" 2>&1 | tee -a $artifact
        missing=$((missing + 1))
    fi
    echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact
}
#register.sv TODO: fix $random warnings
:'
run_tb "tb/tb_register" "register.sv"
'
#top.sv
run_tb "tb/tb_top" "top.sv"

# bimodal_predict.sv branch_predictor.sv
run_tb "rtl/datapath/rtl/if_stage/tb/tb_branch_predictor" "bimodal_predict.sv branch_predictor.sv "

# exe_stage.sv
run_tb "rtl/datapath/rtl/exe_stage/tb/tb_top" "exe_stage.sv"

# mul_unit.sv
# ** multidriven and does not reach end of test
run_tb "rtl/datapath/rtl/exe_stage/tb/tb_mul_unit" "mul_unit.sv"

# div_unit.sv div_4bits.sv
run_tb "rtl/datapath/rtl/exe_stage/tb/tb_div_unit" "div_unit.sv div_4bits.sv "
# datapath.sv
run_tb "rtl/datapath/tb/tb_datapath" "datapath.sv"

#if_stage.sv
run_tb "rtl/datapath/rtl/if_stage/tb/tb_if_stage" "if_stage.sv"

#alu.sv
run_tb "rtl/datapath/rtl/exe_stage/tb/tb_alu" "alu.sv"

#branch_unit.sv
run_tb "rtl/datapath/rtl/exe_stage/tb/tb_branch_unit" "branch_unit.sv"

#interface_dcache.sv
run_tb "rtl/interface_dcache/tb/tb_interface_dcache" "interface_dcache"

# decoder.sv
run_tb "rtl/datapath/rtl/id_stage/tb/tb_decoder" "decoder"

# icache_interface.sv
run_tb "interface_icache/tb/tb_icache_interface" "icache_interface"

# control_unit.sv
run_tb "rtl/control_unit/tb/tb_control_unit" "control_unit"


#if this is not empty CI yellow tick
warnings=$(cat $artifact | grep -i "warnings" | grep -v "Warning: 0")
#if this is not empty CI fail
errors=$(cat $artifact | grep -i error | grep -v "Errors: 0")
#if this is not empty CI fail
fails=$(cat $artifact | grep -i fail | grep -v "Warning: setting ADDR_NO_RANDOMIZE failed - Operation not permitted.")
#Missing files or wrong paths on this scripts
path_error=$(cat $artifact | grep -i "No such file")
#some pass messages shall be present otherwise nothing has run
pass_messages=$(cat $artifact | grep -i "pass\|passed")

# Variables to provide more clear reports, where file names precede the message
name_warnings=$(cat $artifact | grep -i "warnings\|*** results of file:" | grep -v "Warning: 0")
name_errors=$(cat $artifact | grep -i "error\|*** results of file:" | grep -v "Errors: 0")
name_fails=$(cat $artifact | grep -i "fail\|*** results of file:" | grep -v "Warning: setting ADDR_NO_RANDOMIZE failed - Operation not permitted.")
name_path_error=$(cat $artifact | grep -i "No such file\|*** results of file:")
name_pass_messages=$(cat $artifact | grep -i "pass\|passed\|*** results of file:")

#Return value for the error
ret_val=0

echo "errors"
[ -z "$errors" ] 
rval=$?
if [ $rval -ne 0 ]; then
    echo -e "$RED"
    echo "$name_errors"
    echo -e "$NC"
	ret_val+=1
fi

echo "warnings"
[ -z "$warnings" ]
rval=$?
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
    echo "$name_warnings"
    echo -e "$NC"
	ret_val+=0
fi

echo "fails"
[ -z "$fails" ]
rval=$?
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
    echo "$name_fails"
    echo -e "$NC"
	ret_val+=3
fi

echo "path_error"
[ -z "$path_error" ]
rval=$?
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
    echo "$name_path_error"
    echo -e "$NC"
	ret_val+=4
fi

echo "pass_messages"
! [ -z "$pass_messages" ]
rval=$?
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
  	echo -e "$name_pass_messages"
    echo "No pass messages detected"
    echo -e "$NC"
	ret_val+=5
fi

echo "missing_testbench_dirs"
if [ "$missing" -gt 0 ]; then
  	echo -e "$RED"
    echo "$missing testbench directories were missing"
    echo -e "$NC"
	ret_val+=6
fi

echo $ret_val

exit $ret_val
