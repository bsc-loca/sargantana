#!/bin/bash
artifact="/tmp/artifact_lint.log"
#find paths of directories that are called rtl and save them in the format of
#verilator. path -I"other_paths"
include_dirs=""
while read file; do
    include_dirs="$include_dirs -I$file/"
done < <(find ../ -d -name "rtl")


#find rtl files and run linting in each one of them. Formated one file per line
#Exclude tb files and wip
rtl_files=""
while read file; do
    rtl_files=$rtl_files$'\n'$file
done < <(grep -r -l -i --include \*.v --include \*.sv ../ --exclude \tb_* --exclude \wpi_* )

#Keep this only for debug pourpouses, can be removed in the future. TODO
#echo "paths of include_dirs"
#echo "-----------------"
#echo $include_dirs
#echo "paths of rtl_files"
#echo "-----------------"
#echo -e $rtl_files


echo "Verilator lint only"
echo "-----------------"
rm $artifact
while read p; do
  #include all the founded rtl folders as includes in case you have dependences 
  #grep for warnings and errors and save it on a variable. Notice that sterr is 
  #required
  (verilator --lint-only  $include_dirs "$p"| grep 'warning\|error')2>&1 | tee -a $artifact 
done <<< "$rtl_files"

#check if there is an artifact, due to errors or warnings
#if 0 is returned by exit no log has been generated
#else there are errors and pipeline as failed
#this checks if $artifacs exist
! [ -s $artifact ]
#Stores previous return value, inverted.
rval="$?"
exit $rval
