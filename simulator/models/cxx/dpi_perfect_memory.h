// See LICENSE for license details.

#ifndef DPI_PERFECT_MEMORY_H
#define DPI_PERFECT_MEMORY_H

#define BUS_WIDTH 512   // Bus size
#define BUS_ADDR_BITS 6 // Bits needed to address a byte within the bus

#include <svdpi.h>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

extern void memory_read(const svBitVecVal *addr, svBitVecVal *data);

extern void memory_write(const svBitVecVal *addr, const svBitVecVal *byte_enable, const svBitVecVal *data);

extern void memory_amo(const svBitVecVal *addr, const svBitVecVal *size, const svBitVecVal *amo_op, const svBitVecVal *data, svBitVecVal *result);

#ifdef __cplusplus
}
#endif

void memory_init(std::string filename);

void memory_enable_read_debug();

std::string memory_symbol_from_addr(uint64_t addr);

#endif //DPI_PERFECT_MEMORY_H