// See LICENSE for license details.

#ifndef DPI_PERFECT_MEMORY_H
#define DPI_PERFECT_MEMORY_H

#define BUS_WIDTH 128

#include <svdpi.h>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif

extern svBit memory_read(const svBitVecVal *addr, svBitVecVal *data);

extern svBit memory_write(const svBitVecVal *addr, const svBitVecVal *size, const svBitVecVal *data);

#ifdef __cplusplus
}
#endif

void memory_init(std::string filename);

void memory_enable_read_debug();

std::string memory_symbol_from_addr(uint64_t addr);

#endif //DPI_PERFECT_MEMORY_H