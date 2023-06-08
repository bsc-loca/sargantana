// See LICENSE for license details.

#ifndef DPI_TORTURE_H
#define DPI_TORTURE_H

#include "riscv/isa_parser.h"
#include <svdpi.h>
#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <string>
#include <riscv/disasm.h>

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

// WARNING!!!
// The fields in this struct *MUST* be the reverse of the one in drac_pkg.sv
typedef struct {
    unsigned long long fflags_wr_valid;
    unsigned long long mem_addr;
    unsigned long long mem_type;
    unsigned long long csr_tval;
    unsigned long long csr_xcpt_cause;
    unsigned long long csr_xcpt;
    unsigned long long csr_rw_data;
    unsigned long long csr_priv_lvl;
    unsigned long long xcpt_cause;
    unsigned long long xcpt;
    unsigned long long sew;
    unsigned long long csr_data;
    unsigned long long csr_dst;
    unsigned long long csr_wr_valid;
    uint32_t data[128/32];
    unsigned long long vreg_wr_valid;
    unsigned long long freg_wr_valid;
    unsigned long long reg_wr_valid;
    unsigned long long vdst;
    unsigned long long fdst;
    unsigned long long dst;
    unsigned long long inst;
    unsigned long long pc;
} commit_data_t;

extern void torture_dump (unsigned long long cycles, const commit_data_t *commit_data);

  #ifndef INCISIVE_SIMULATION
  extern void torture_signature_init(const char* binaryFileName);
  #else
  extern void torture_signature_init();
  #endif
extern void check_deadlock (unsigned long long cycles, unsigned long long PC, unsigned long long commit_valid);
extern void csr_change(unsigned long long addr, unsigned long long value);
extern void torture_dump_amo_write(const svBitVecVal *addr, const svBitVecVal *size, const svBitVecVal *data);
#ifdef __cplusplus
}
#endif

// Class to hold the torture signature
class tortureSignature {
uint64_t * signature; // vector to hold the register file status
std::ofstream signatureFile; // file where the info is dumped
std::string signatureFileName = "signature.txt";
disassembler_t *disassembler;
isa_parser_t *isa;
uint64_t debug_addr = 0;
bool dump_valid = true;
uint64_t max_miss = 0;
bool first_missmatch = false;

public:
tortureSignature()
{
	signature = (uint64_t*) calloc(32,sizeof(uint64_t));
  isa = new isa_parser_t("rv64imaf", "msu");
  disassembler = new disassembler_t(isa);
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

void dump_file(unsigned long long cycles, const commit_data_t *commit_data);

void dump_xcpt(uint64_t xcpt_cause, uint64_t epc, uint64_t tval);

void dump_spike(uint64_t PC, uint64_t inst, uint64_t dst, uint64_t dst_value);
};

// Global torture_signature
extern tortureSignature *torture_signature;

#endif
