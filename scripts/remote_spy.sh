#!/bin/bash
#Format parameters
FN="$(basename -- $1)"
N="${FN%%.*}"
EX="${FN#*.}"
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
DIR="spyglass_reports"
TOP="top_drac"
#echo $FN
#echo $N
#echo $EX
#cleanup in local and remote machines
rm -rf ./spyglass_reports 
rm -rf /tmp/importspy
rm -rf /tmp/optionsspy
ssh drac@192.168.10.38 << EOF
rm -rf /tmp/$N
#make destination folder
mkdir /tmp/$N
exit
EOF
#copy files and set script
for var in "$@"
do
	echo "read_file -type verilog {./"$(basename -- $var)"}" >> /tmp/importspy 
	scp -o PasswordAuthentication=no -o ConnectTimeout=4 -o BatchMode=yes $var drac@192.168.10.38:/tmp/$N
done
#set the top for spyglass. must be the first argument of the script.
echo "set_option top $TOP" >> /tmp/optionsspy 
echo "set_parameter handle_large_bus yes" >> /tmp/optionsspy 
scp -o PasswordAuthentication=no -o ConnectTimeout=4 -o BatchMode=yes /tmp/importspy drac@192.168.10.38:/tmp
scp -o PasswordAuthentication=no -o ConnectTimeout=4 -o BatchMode=yes /tmp/optionsspy drac@192.168.10.38:/tmp
ssh drac@192.168.10.38 << EOF
cp /home/drac/guillem/template_spyglass.prj /tmp/$N/$N.prj
cd /tmp/$N
sed -i '/Data Import Section/ r /tmp/importspy' ./$N.prj
sed -i '/Common Options Section/ r /tmp/optionsspy' ./$N.prj
export SKIP_PLATFORM_CHECK=TRUE
export LM_LICENSE_FILE=27020@84.88.187.145
export SNPS_LICENSE_FILE=27020@epi01.bsc.es
export SNPSLMD_LICENSE_FILE=27020@epi01.bsc.es
export PATH='$PATH:/home/drac/synopsys/install/spyglass/SPYGLASS2018.09-SP1-1/SPYGLASS_HOME/bin/'
echo -e "exports\n"
echo -e "run_goal lint/lint_rtl\nexit -save\n"| spyglass_main -shell -project $N.prj   
echo -e "remove\n"
exit
EOF
echo -e "exit"
scp -o PasswordAuthentication=no -o ConnectTimeout=4 -o BatchMode=yes -r drac@192.168.10.38:/tmp/$N/$N ./spyglass_reports
echo -e "copy resuts"
cat spyglass_reports/consolidated_reports/top_drac_lint_lint_rtl/moresimple.rpt | grep -i 'warning\|error' 2>&1

#check if the log has no errors
tmp=$(grep -r -i "Reported Messages:         0 Fatals,   0 Errors,     0 Warnings," spyglass_reports/)
#check if we have find "Reported Messages:         0 Fatals,   0 Errors,     0 Warnings"
! [ -n $tmp ]
rval=$?
#if empty rval
if [ $rval -ne 0 ]; then
  	echo -e "$RED"
	grep -r -i "Reported Messages:" ./$DIR/$TOP/lint/lint_rtl/spyglass.log
  	echo -e "$NC"
	exit 1
fi
exit 0

