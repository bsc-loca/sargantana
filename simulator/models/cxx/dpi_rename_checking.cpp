#include "dpi_rename_checking.h"
#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#include "globals.h"

#define HEX_PC( x ) "0x" << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define HEX_INST( x ) "0x" << std::setw(8) << std::setfill('0') << std::hex << (long)( x )
#define HEX_DATA( x ) "0x" << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define HEX_VDATA( x ) std::setw(8) << std::setfill('0') << std::hex << (long)( x )
#define DEC_DST( x ) "x" << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_FDST( x ) "f" << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_VDST( x ) "v" << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_PRIV( x ) std::setw(1) << std::dec << (long)( x )

// Global objects
int cycles_rename = 0;
rename_checking *rename_checking_int;

// System Verilog DPI
void rename_checking_dump (unsigned long long r0, unsigned long long r1, unsigned long long r2, unsigned long long r3, 
                            unsigned long long r4, unsigned long long r5, unsigned long long r6, unsigned long long r7, 
                            unsigned long long r8, unsigned long long r9, unsigned long long r10, unsigned long long r11, 
                            unsigned long long r12, unsigned long long r13, unsigned long long r14, unsigned long long r15, 
                            unsigned long long r16, unsigned long long r17, unsigned long long r18, unsigned long long r19, 
                            unsigned long long r20, unsigned long long r21, unsigned long long r22, unsigned long long r23, 
                            unsigned long long r24, unsigned long long r25, unsigned long long r26, unsigned long long r27, 
                            unsigned long long r28, unsigned long long r29, unsigned long long r30, unsigned long long r31, 
                            unsigned long long head, unsigned long long tail, unsigned long long num){
    cycles_rename++;
    if(rename_checking_int->dump_check()){
        rename_checking_int->dump_file(r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, 
                            r15, r16, r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, 
                            r27, r28, r29, r30, r31, head, tail, num);
    }
}

void rename_checking_init(){
    rename_checking_int = new rename_checking;
}

// RENAME_CHECKING
void rename_checking::disable()
{
    dump_valid = false;
}

bool rename_checking::dump_check()
{
    return dump_valid;
}

void rename_checking::dump_file(unsigned long long r0, unsigned long long r1, unsigned long long r2, unsigned long long r3, 
                            unsigned long long r4, unsigned long long r5, unsigned long long r6, unsigned long long r7, 
                            unsigned long long r8, unsigned long long r9, unsigned long long r10, unsigned long long r11, 
                            unsigned long long r12, unsigned long long r13, unsigned long long r14, unsigned long long r15, 
                            unsigned long long r16, unsigned long long r17, unsigned long long r18, unsigned long long r19, 
                            unsigned long long r20, unsigned long long r21, unsigned long long r22, unsigned long long r23, 
                            unsigned long long r24, unsigned long long r25, unsigned long long r26, unsigned long long r27, 
                            unsigned long long r28, unsigned long long r29, unsigned long long r30, unsigned long long r31, 
                            unsigned long long head, unsigned long long tail, unsigned long long num){

    // fer vector
    int hit[32];

    int regs[32];

    regs[0] = r0;
    regs[1] = r1;
    regs[2] = r2;
    regs[3] = r3;
    regs[4] = r4;
    regs[5] = r5;
    regs[6] = r6;
    regs[7] = r7;
    regs[8] = r8;
    regs[9] = r9;
    regs[10] = r10;
    regs[11] = r11;
    regs[12] = r12;
    regs[13] = r13;
    regs[14] = r14;
    regs[15] = r15;
    regs[16] = r16;
    regs[17] = r17;
    regs[18] = r18;
    regs[19] = r19;
    regs[20] = r20;
    regs[21] = r21;
    regs[22] = r22;
    regs[23] = r23;
    regs[24] = r24;
    regs[25] = r25;
    regs[26] = r26;
    regs[27] = r27;
    regs[28] = r28;
    regs[29] = r29;
    regs[30] = r30;
    regs[31] = r31;

    for (int i=0; i<32;i++){
        hit[i] = 0;
    }

    for (int i=0; i<num;i++){
        int index = (head + 1) % 32;
        if ( hit[regs[index]] > 0){
            std::cout << "The register:" << std::dec << regs[index] << "is duplicated on the cycle\t" << std::dec << cycles_rename << "\n";
            finish_due_renaming_error = 1;
        }else{
            hit[regs[index]]++;
        }
    }
}
