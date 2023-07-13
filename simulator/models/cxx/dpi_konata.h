// See LICENSE for license details.

#ifndef DPI_KONATA_H
#define DPI_KONATA_H

#include <svdpi.h>
#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

  extern void konata_dump (unsigned long long if1_valid,
                            unsigned long long if2_valid,
                            unsigned long long id_valid,
                            unsigned long long ir_valid,
                            unsigned long long rr_valid,
                            unsigned long long exe_valid,
                            unsigned long long wb1_valid,
                            unsigned long long wb2_valid,
                            unsigned long long wb3_valid,
                            unsigned long long wb4_valid,
                            unsigned long long wb1_fp_valid,
                            unsigned long long wb2_fp_valid,
                            unsigned long long wb1_simd_valid,
                            unsigned long long wb2_simd_valid,
                            unsigned long long wb_store_valid,
                            unsigned long long if1_stall,
                            unsigned long long if2_stall,
                            unsigned long long id_stall,
                            unsigned long long ir_stall,
                            unsigned long long rr_stall,
                            unsigned long long exe_stall,
                            unsigned long long if1_flush,
                            unsigned long long if2_flush,
                            unsigned long long id_flush,
                            unsigned long long ir_flush,
                            unsigned long long rr_flush,
                            unsigned long long exe_flush, 
                            unsigned long long id_pc,
                            unsigned long long id_inst,
                            unsigned long long if1_id,
                            unsigned long long if2_id,
                            unsigned long long id_id,
                            unsigned long long ir_id,
                            unsigned long long rr_id,
                            unsigned long long exe_id, 
                            unsigned long long exe_unit,
                            unsigned long long wb1_id,
                            unsigned long long wb2_id,
                            unsigned long long wb3_id,
                            unsigned long long wb4_id,
                            unsigned long long wb1_fp_id,
                            unsigned long long wb2_fp_id,
                            unsigned long long wb1_simd_id,
                            unsigned long long wb2_simd_id,
                            unsigned long long wb_store_id);
  extern void konata_signature_init();
#ifdef __cplusplus
}
#endif

// Class to hold the torture signature
class konataSignature {
uint64_t * signature; // vector to hold the register file status
std::ofstream signatureFile; // file where the info is dumped
std::string signatureFileName = "konata.txt";
bool dump_valid = true;

public:
konataSignature()
{
	signature = (uint64_t*) calloc(32,sizeof(uint64_t));
}

virtual ~konataSignature() { free(signature); }

void disable();

void set_dump_file_name(std::string name);

bool dump_check();

void clear_output();

void dump_file(unsigned long long if1_valid,
                            unsigned long long if2_valid,
                            unsigned long long id_valid,
                            unsigned long long ir_valid,
                            unsigned long long rr_valid,
                            unsigned long long exe_valid,
                            unsigned long long wb1_valid,
                            unsigned long long wb2_valid,
                            unsigned long long wb3_valid,
                            unsigned long long wb4_valid,
                            unsigned long long wb1_fp_valid,
                            unsigned long long wb2_fp_valid,
                            unsigned long long wb1_simd_valid,
                            unsigned long long wb2_simd_valid,
                            unsigned long long wb_store_valid,
                            unsigned long long if1_stall,
                            unsigned long long if2_stall,
                            unsigned long long id_stall,
                            unsigned long long ir_stall,
                            unsigned long long rr_stall,
                            unsigned long long exe_stall,
                            unsigned long long if1_flush,
                            unsigned long long if2_flush,
                            unsigned long long id_flush,
                            unsigned long long ir_flush,
                            unsigned long long rr_flush,
                            unsigned long long exe_flush, 
                            unsigned long long id_pc,
                            unsigned long long id_inst,
                            unsigned long long if1_id,
                            unsigned long long if2_id,
                            unsigned long long id_id,
                            unsigned long long ir_id,
                            unsigned long long rr_id,
                            unsigned long long exe_id, 
                            unsigned long long exe_unit,
                            unsigned long long wb1_id,
                            unsigned long long wb2_id,
                            unsigned long long wb3_id,
                            unsigned long long wb4_id,
                            unsigned long long wb1_fp_id,
                            unsigned long long wb2_fp_id,
                            unsigned long long wb1_simd_id,
                            unsigned long long wb2_simd_id,
                            unsigned long long wb_store_id);
};

// Global konata_signature
extern konataSignature *konata_signature;

#endif
