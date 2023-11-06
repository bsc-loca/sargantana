#!/bin/bash
#This script will lint all the verilog and sv files with verilator til an error
# is found. No artefacts are made.

#find paths of directories that are called rtl and save them in the format of
#verilator. path -I"other_paths"
include_dirs=""
while read file; do
    include_dirs="$include_dirs -I$file/"
done < <(find ./ -depth -name "includes" -o -name "rtl")


#find rtl files and run linting in each one of them. Formated one file per line
#Exclude tb files and wip
rtl_files=""
while read file; do
    rtl_files=$rtl_files$file$'\n'
done < <(find   \( ! -iname \tb_* -a ! -iname \wip_* -a ! -iname \*_pkg\* -a ! -path \*/tb* \) -and \( -iname \*.v -o -iname \*.vh -o -iname \*.sv \))
#remove the last character (empty), If not verilator will try to run without 
#a valid file name
rtl_files=${rtl_files::-1}

echo "Verilator lint only"
echo "-----------------"
while read p; do
  #include all the founded rtl folders as includes in case you have dependences 
  #grep for warnings and errors and save it on a variable. Notice that sterr is 
  #required
  (verilator --lint-only  includes/riscv_pkg.sv includes/drac_pkg.sv $include_dirs "$p") 
  #Detect if there was an error in previous command
  if [ "$?" -ne "0" ]; then
   exit 1
  fi
done <<< "$rtl_files"

exit 0
