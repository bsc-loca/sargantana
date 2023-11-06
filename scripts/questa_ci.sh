#!/bin/bash
#runs all the questa TB and reports PASS or FAIL messages
#Testbench require to finish with $finish; to be non interactive
#An artifact with the errors is generated
artifact="/tmp/artifact_questa.log"
RED='\033[0;31m'         
GREEN='\033[0;32m'       
NC='\033[0m' # No Color  
TOP=$PWD
#register.sv TODO: fix $random warnings
:'
echo "*** results of file: register.sv" 2>&1 | tee -a $artifact
cd $TOP/tb/tb_register
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact
'
#top.sv
echo "*** results of file: top.sv" 2>&1 | tee -a $artifact
cd $TOP/tb/tb_top
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

# bimodal_predict.sv branch_predictor.sv
echo "*** results of file: bimodal_predict.sv branch_predictor.sv " 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/rtl/if_stage/tb/tb_branch_predictor
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

# exe_stage.sv
echo "*** results of file: exe_stage.sv" 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_top/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

# mul_unit.sv
# ** multidriven and does not reach end of test
echo "*** results of file: mul_unit.sv" 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_mul_unit/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

# div_unit.sv div_4bits.sv
echo "*** results of file: div_unit.sv div_4bits.sv " 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_div_unit/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact
# datapath.sv
echo "*** results of file: datapath.sv" 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/tb/tb_datapath/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

#if_stage.sv
echo "*** results of file: if_stage.sv" 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/rtl/if_stage/tb/tb_if_stage/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

#alu.sv
echo "*** results of file: alu.sv" 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_alu/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

#branch_unit.sv
echo "*** results of file: branch_unit.sv" 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_branch_unit/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

#interface_dcache.sv
echo "*** results of file: interface_dcache" 2>&1 | tee -a $artifact
cd $TOP/rtl/interface_dcache/tb/tb_interface_dcache/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

# decoder.sv
echo "*** results of file: decoder" 2>&1 | tee -a $artifact
cd $TOP/rtl/datapath/rtl/id_stage/tb/tb_decoder/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

# icache_interface.sv
echo "*** results of file: icache_interface" 2>&1 | tee -a $artifact
cd $TOP/interface_icache/tb/tb_icache_interface/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact

# control_unit.sv
echo "*** results of file: control_unit" 2>&1 | tee -a $artifact
cd $TOP/rtl/control_unit/tb/tb_control_unit/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********" 2>&1 | tee -a $artifact


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

echo $ret_val

exit $ret_val
