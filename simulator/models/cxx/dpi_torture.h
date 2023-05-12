// See LICENSE for license details.

#ifndef DPI_TORTURE_H
#define DPI_TORTURE_H

#include <svdpi.h>
#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <string>

#define CAUSE_MISALIGNED_FETCH 0x0
#define CAUSE_FAULT_FETCH 0x1
#define CAUSE_ILLEGAL_INSTRUCTION 0x2
#define CAUSE_BREAKPOINT 0x3
#define CAUSE_MISALIGNED_LOAD 0x4
#define CAUSE_FAULT_LOAD 0x5
#define CAUSE_MISALIGNED_STORE 0x6
#define CAUSE_FAULT_STORE 0x7
#define CAUSE_USER_ECALL 0x8
#define CAUSE_SUPERVISOR_ECALL 0x9
#define CAUSE_MACHINE_ECALL 0xB
#define CAUSE_INSTR_PAGE_FAULT 0xC
#define CAUSE_LD_PAGE_FAULT 0xD
#define CAUSE_ST_AMO_PAGE_FAULT 0xF

#define VVLEN 128

#ifdef __cplusplus
extern "C" {
#endif

struct dpi_param_t {
    uint32_t data0;
    uint32_t data1;
    uint32_t data2;
    uint32_t data3;
};

extern void torture_dump (unsigned long long cycles, unsigned long long PC, unsigned long long inst, unsigned long long dst, unsigned long long fdst,
                            unsigned long long vdst, unsigned long long reg_wr_valid, unsigned long long freg_wr_valid, unsigned long long vreg_wr_valid,
                            unsigned int data0, unsigned int data1, unsigned int data2, unsigned int data3,
                            unsigned long long sew, unsigned long long xcpt, unsigned long long xcpt_cause, unsigned long long csr_priv_lvl, unsigned long long csr_rw_data, unsigned long long csr_xcpt, unsigned long long csr_xcpt_cause, unsigned long long csr_tval
                           );
  #ifndef INCISIVE_SIMULATION
  extern void torture_signature_init(const char* binaryFileName);
  #else
  extern void torture_signature_init();
  #endif
extern void check_deadlock (unsigned long long cycles, unsigned long long PC, unsigned long long commit_valid);
#ifdef __cplusplus
}
#endif

// Class to hold the torture signature
class tortureSignature {
uint64_t * signature; // vector to hold the register file status
std::ofstream signatureFile; // file where the info is dumped
std::string signatureFileName = "signature.txt";
uint64_t debug_addr = 0;
bool dump_valid = true;
uint64_t max_miss = 0;
bool first_missmatch = false;

public:
tortureSignature()
{
	signature = (uint64_t*) calloc(32,sizeof(uint64_t));
}

virtual ~tortureSignature() { free(signature); }

void disable();

void set_dump_file_name(std::string name);

void set_debug_addr(std::string addr);

void set_max_miss(std::string miss);

void set_first_missmatch(bool conf);

bool dump_check();

uint64_t get_debug_addr();

uint64_t get_max_miss();

bool get_first_missmatch();

void clear_output();

void update_signature(uint64_t dst, uint64_t data);

void dump_file(uint64_t PC, uint64_t inst, uint64_t dst, uint64_t fdst, uint64_t vdst, uint64_t reg_wr_valid, uint64_t freg_wr_valid,
              uint64_t vreg_wr_valid, uint64_t xcpt, uint64_t xcpt_cause,
              uint32_t data0, uint32_t data1, uint32_t data2, uint32_t data3,
              uint64_t sew, uint64_t csr_priv_lvl, uint64_t csr_rw_data, uint64_t csr_tval);

void dump_xcpt(uint64_t xcpt_cause, uint64_t epc, uint64_t tval);

void dump_spike(uint64_t PC, uint64_t inst, uint64_t dst, uint64_t dst_value);
};

// Global torture_signature
extern tortureSignature *torture_signature;

#endif
