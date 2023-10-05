#include "dpi_host.h"

#include <iostream>
#include <unistd.h>

#include "dpi_perfect_memory.h"

// Commands definition
#define SYS_write 64

static uint64_t fromhostAddr = 0;

int tohost(const svBitVecVal *svdata) {
    if(fromhostAddr == 0) fromhostAddr = memory_dpi_get_symbol_addr("fromhost");
    
    uint64_t data = ((uint64_t) svdata[1]) << 32 | svdata[0];

    if (data & 1) return 1; // Simulation finished

    // Handle the syscall

    uint64_t magicmem[8];
    uint32_t upper, lower;

    for (unsigned int i = 0; i < 8; i++) {
        lower = memory_dpi_read_contents((data + i*8));
        upper = memory_dpi_read_contents((data + i*8) + 4);
        magicmem[i] = ((uint64_t) upper) << 32 | lower;
    }

    switch (magicmem[0]) {
        case SYS_write:
        {
            uint64_t length = magicmem[3];
            char buf[length];
            for (unsigned int i = 0; i < length; i++) {
                uint32_t data = memory_dpi_read_contents(magicmem[2] + (i & ~0b11));
                buf[i] = data >> ((i%4) * 8);
            }
            uint64_t result = write(magicmem[1], buf, length);
            memory_dpi_write_contents(fromhostAddr, result & 0xffffffff);
            memory_dpi_write_contents(fromhostAddr + 4, (result >> 32) & 0xffffffff);
            break;
        }
        default:
            std::cerr << "Unknown tohost syscall " << std::hex << magicmem[0] << std::endl;
    }

    return 0;
}