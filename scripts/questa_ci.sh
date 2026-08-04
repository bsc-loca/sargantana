#!/bin/bash
#runs all the questa TB and reports PASS or FAIL messages
#Testbench require to finish with $finish; to be non interactive
#An artifact with the errors is generated
artifact="/tmp/artifact_questa.log"
RED='\033[0;31m'         
GREEN='\033[0;32m'       
NC='\033[0m' # No Color  
TOP=$PWD

rm -f $artifact

run_testbench() {
    local label="$1"
    local dir="$2"
    echo "*** results of file: $label" 2>&1 | tee -a "$artifact"
    if cd "$TOP/$dir" 2>/dev/null; then
        (./runtest.sh -c ) 2>&1 | tee -a "$artifact"
        echo "******** questasim test has finish for this file **********" 2>&1 | tee -a "$artifact"
    else
        echo "ERROR: Directory $TOP/$dir not found" 2>&1 | tee -a "$artifact"
        exit 1
    fi
}

#register.sv TODO: fix $random warnings
:'
run_testbench "register.sv" "tb/tb_register"
'
#top.sv
run_testbench "top.sv" "tb/tb_top"

# if_stage_1 bimodal_predict.sv branch_predictor.sv
run_testbench "if_stage_1 bimodal_predict.sv branch_predictor.sv" "rtl/datapath/rtl/if_stage_1/tb/tb_branch_predictor"

# if_stage_1 if_stage.sv
run_testbench "if_stage_1 if_stage.sv" "rtl/datapath/rtl/if_stage_1/tb/tb_if_stage"

# if_stage_2 bimodal_predict.sv branch_predictor.sv
run_testbench "if_stage_2 bimodal_predict.sv branch_predictor.sv" "rtl/datapath/rtl/if_stage_2/tb/tb_branch_predictor"

# if_stage_2 if_stage.sv
run_testbench "if_stage_2 if_stage.sv" "rtl/datapath/rtl/if_stage_2/tb/tb_if_stage"

# exe_stage.sv
run_testbench "exe_stage.sv" "rtl/datapath/rtl/exe_stage/tb/tb_top/"

# mul_unit.sv
# ** multidriven and does not reach end of test
run_testbench "mul_unit.sv" "rtl/datapath/rtl/exe_stage/tb/tb_mul_unit/"

# div_unit.sv div_4bits.sv
run_testbench "div_unit.sv div_4bits.sv" "rtl/datapath/rtl/exe_stage/tb/tb_div_unit/"

# datapath.sv
run_testbench "datapath.sv" "rtl/datapath/tb/tb_datapath/"

#alu.sv
run_testbench "alu.sv" "rtl/datapath/rtl/exe_stage/tb/tb_alu/"

#branch_unit.sv
run_testbench "branch_unit.sv" "rtl/datapath/rtl/exe_stage/tb/tb_branch_unit/"

# decoder.sv
run_testbench "decoder" "rtl/datapath/rtl/id_stage/tb/tb_decoder/"

# control_unit.sv
run_testbench "control_unit" "rtl/control_unit/tb/tb_control_unit/"


#if this is not empty CI yellow tick
warnings=$(cat $artifact | grep -i "warnings" | grep -v "Warning: 0")
#if this is not empty CI fail
errors=$(cat $artifact | grep -i error | grep -v "Errors: 0")
#if this is not empty CI fail
fails=$(cat $artifact | grep -i fail | grep -v "Warning: setting ADDR_NO_RANDOMIZE failed - Operation not permitted.")
#Missing files or wrong paths on this scripts
path_error=$(cat $artifact | grep -i "No such file\|ERROR: Directory")
#some pass messages shall be present otherwise nothing has run
pass_messages=$(cat $artifact | grep -i "pass\|passed")

# Variables to provide more clear reports, where file names precede the message
name_warnings=$(cat $artifact | grep -i "warnings\|*** results of file:" | grep -v "Warning: 0")
name_errors=$(cat $artifact | grep -i "error\|*** results of file:" | grep -v "Errors: 0")
name_fails=$(cat $artifact | grep -i "fail\|*** results of file:" | grep -v "Warning: setting ADDR_NO_RANDOMIZE failed - Operation not permitted.")
name_path_error=$(cat $artifact | grep -i "No such file\|ERROR: Directory\|*** results of file:")
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

echo $ret_val

exit $ret_val
