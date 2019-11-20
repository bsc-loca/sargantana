#!/bin/bash
#This script will lint all the verilog and sv files with verilator
#An artifact with the errors is generated
artifact="/tmp/artifact_lint.log"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
#TODO: this script only works if used from the top directory
TOP="./"
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
echo "Verilator lint only"
echo "-----------------"
rm $artifact
while read p; do
  #include all the founded rtl folders as includes in case you have dependences 
  #grep for warnings and errors and save it on a variable. Notice that sterr is 
  #required
  echo -e "$GREEN $p $NC"
  #(/home/bscuser/programs/scripts/runLintSV.sh   includes/riscv_pkg.sv includes/drac_pkg.sv "$p"| grep 'warning\|error')2>&1 | tee -a $artifact 
done <<< "$rtl_files"

$TOP/scripts/remote_spy.sh includes/riscv_pkg.sv includes/drac_pkg.sv $rtl_files

#check if there is an artifact, due to errors or warnings
#if 0 is returned by exit no log has been generated
#else there are errors and pipeline as failed
#this checks if $artifacs exist
! [ -s $artifact ]
#Stores previous return value, inverted.
rval="$?"
exit $rval
