// See LICENSE for license details.

#ifndef DPI_RENAME_CHECKING_H
#define DPI_RENAME_CHECKING_H

#include <svdpi.h>
#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

  extern void rename_checking_dump (unsigned long long r0, unsigned long long r1, unsigned long long r2, unsigned long long r3, 
                            unsigned long long r4, unsigned long long r5, unsigned long long r6, unsigned long long r7, 
                            unsigned long long r8, unsigned long long r9, unsigned long long r10, unsigned long long r11, 
                            unsigned long long r12, unsigned long long r13, unsigned long long r14, unsigned long long r15, 
                            unsigned long long r16, unsigned long long r17, unsigned long long r18, unsigned long long r19, 
                            unsigned long long r20, unsigned long long r21, unsigned long long r22, unsigned long long r23, 
                            unsigned long long r24, unsigned long long r25, unsigned long long r26, unsigned long long r27, 
                            unsigned long long r28, unsigned long long r29, unsigned long long r30, unsigned long long r31, 
                            unsigned long long head, unsigned long long tail, unsigned long long num);
  extern void rename_checking_init();
#ifdef __cplusplus
}
#endif

// Class to hold the rename_checking signature
class rename_checking {
bool dump_valid = true;

public:

virtual ~rename_checking() {}

void disable();

bool dump_check();

void dump_file(unsigned long long r0, unsigned long long r1, unsigned long long r2, unsigned long long r3, 
                            unsigned long long r4, unsigned long long r5, unsigned long long r6, unsigned long long r7, 
                            unsigned long long r8, unsigned long long r9, unsigned long long r10, unsigned long long r11, 
                            unsigned long long r12, unsigned long long r13, unsigned long long r14, unsigned long long r15, 
                            unsigned long long r16, unsigned long long r17, unsigned long long r18, unsigned long long r19, 
                            unsigned long long r20, unsigned long long r21, unsigned long long r22, unsigned long long r23, 
                            unsigned long long r24, unsigned long long r25, unsigned long long r26, unsigned long long r27, 
                            unsigned long long r28, unsigned long long r29, unsigned long long r30, unsigned long long r31, 
                            unsigned long long head, unsigned long long tail, unsigned long long num);

};

// Global rename_checking_signature
extern rename_checking *rename_checking_int;

#endif
