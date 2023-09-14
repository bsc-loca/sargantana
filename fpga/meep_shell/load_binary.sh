#!/bin/bash

# This script loads a binary to the FPGA's memory and applies a reset to the
# core, essentially booting it and executing the binary.

set -x

FILENAME=$1
FILESIZE=$(du -b $FILENAME | cut -f1)

echo "******************************"
echo "*** Sargantana Boot Script ***"
echo "******************************"

echo -e "Booting using $FILENAME image file which is $FILESIZE bytes\r\n"

echo "*** Resetting core ***"
dma-ctl qdma08000 reg write bar 2 0x0 0x0
sleep 1

echo "*** Uploading binary into main memory ***"
# Bootrom makes the core jump to address 0x8000_0000, which is translated to HBM
# address 0x0000_0000. Thus, the binary must start at address zero.
dma-to-device -v -d /dev/qdma08000-MM-1 -s $FILESIZE -a 0x0000000 -f $FILENAME
sleep 1

echo "*** Releasing core's reset ***"
dma-ctl qdma08000 reg write bar 2 0x0 0x1
