#!/bin/bash
#runs all the questa TB and reports PASS or FAIL messages
#Testbench require to finish with $finish; to be non interactive
#An artifact with the errors is generated
artifact="/tmp/artifact_questa.log"
RED='\033[0;31m'         
GREEN='\033[0;32m'       
NC='\033[0m' # No Color  
TOP=$PWD
#register.sv
echo "*** results of file: register.sv"
cd $TOP/tb/tb_register
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

# bimodal_predict.sv branch_predictor.sv
echo "*** results of file: bimodal_predict.sv branch_predictor.sv "
cd $TOP/rtl/datapath/rtl/if_stage/tb/tb_branch_predictor
# ** Does not have pass message and bitwidth missmatch. 
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

# exe_stage.sv
echo "*** results of file: exe_stage.sv"
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_top/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

# mul_unit.sv
# ** multidriven and does not reach end of test
echo "*** results of file: mul_unit.sv"
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_mul_unit/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

# div_unit.sv div_4bits.sv
echo "*** results of file: div_unit.sv div_4bits.sv "
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_div_unit/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

# datapath.sv
echo "*** results of file: datapath.sv"
cd $TOP/rtl/datapath/tb/tb_datapath/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

# datapath_with cache interface
#echo "*** results of file: datapath_with cache interface"
#cd $TOP/rtl/datapath/tb/tb_datapath_dcache/
#(./runtest.sh -c ) 2>&1 | tee -a $artifact
#echo "******** questasim test has finish for this file **********"

#if_stage.sv
echo "*** results of file: if_stage.sv"
cd $TOP/rtl/datapath/rtl/if_stage/tb/tb_if_stage/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

#alu.sv
echo "*** results of file: alu.sv"
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_alu/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

#branch_unit.sv
echo "*** results of file: branch_unit.sv"
cd $TOP/rtl/datapath/rtl/exe_stage/tb/tb_branch_unit/
(./runtest.sh -c ) 2>&1 | tee -a $artifact
echo "******** questasim test has finish for this file **********"

#if this is not empty CI yellow tick
warnings=$(cat $artifact | grep -i warnings | grep -v "Warning: 0")
#if this is not empty CI fail
errors=$(cat $artifact | grep -i error | grep -v "Errors: 0")
#if this is not empty CI fail
fails=$(cat $artifact | grep -i fail | grep -v "Warning: setting ADDR_NO_RANDOMIZE failed - Operation not permitted.")
#Missing files or wrong paths on this scripts
path_error=$(cat $artifact | grep -i "No such file")
#some pass messages shall be present otherwise nothing has run
pass_messages=$(cat $artifact | grep -i "pass\|passed")

#Return value for the error
ret_val=0

echo "errors"
[ -z "$errors" ] 
rval=$?
if [ $rval -ne 0 ]; then
    echo -e "$RED"
    echo "$errors"
    echo -e "$NC"
	ret_val+=1
fi

echo "warnings"
[ -z "$warnings" ]
rval=$?
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
    echo "$warnings"
    echo -e "$NC"
	ret_val+=2
fi

echo "fails"
[ -z "$fails" ]
rval=$?
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
    echo "$fails"
    echo -e "$NC"
	ret_val+=3
fi

echo "path_error"
[ -z "$path_error" ]
rval=$?
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
    echo "$path_error"
    echo -e "$NC"
	ret_val+=4
fi

echo "pass_messages"
! [ -z "$pass_messages" ]
rval=$?
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
  	echo -e "$pass_messages"
    echo "No pass messages detected"
    echo -e "$NC"
	ret_val+=5
fi

echo $ret_val

exit $ret_val
