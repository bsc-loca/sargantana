#include "dpi_perfect_memory.h"

#include <map>
#include <cstdint>
#include <cassert>

#include "loadelf.hpp"

class Memory32 {                    // data width = 32-bit
    std::map<uint32_t, uint32_t> mem; // memory storage
    uint32_t addr_max;          // the maximal address, 0 means all 32-bit

    public:
        Memory32(uint32_t addr_max) : addr_max(addr_max) {}

        Memory32() : addr_max(0) {}

        // initialize a memory location with a value
        void init(const uint32_t addr, const uint32_t &data) { mem[addr] = data; }

        // write a value
        bool write(const uint32_t addr, const uint32_t &data, const uint32_t &mask);
            // burst write
        void write_block(uint32_t addr, uint32_t size, const uint8_t* buf);
        // read a value
        bool read(const uint32_t addr, uint32_t &data);

        uint32_t max_addr() const { return addr_max; }
};

static Memory32 memoryContents;

svBit memory_read(const svBitVecVal *addr, svBitVecVal *data) {
    uint32_t baseAddress = addr[0];

    for (unsigned int i = 0; i < BUS_WIDTH / 32; i++) {
        uint32_t dataRead;
        memoryContents.read(baseAddress + i * 4, dataRead);
        data[i] = dataRead;
    }

    return sv_1;
}

svBit memory_write(const svBitVecVal *addr, const svBitVecVal *size, const svBitVecVal *data) {
    uint32_t baseAddress = addr[0];

    uint32_t alignedAddress = baseAddress & ~0b11;
    unsigned int offset = baseAddress & 0b11;

    switch(size[0]) {
        case 0:
            memoryContents.write(alignedAddress, data[0] << (8 * offset), 0b1 << offset);
        break;
        case 1:
            memoryContents.write(alignedAddress, data[0] << (8 * offset), 0b11 << offset);
        break;
        case 2:
            memoryContents.write(alignedAddress, data[0], 0b1111);
        break;
        case 3:
            memoryContents.write(alignedAddress, data[0], 0b1111);
            memoryContents.write(alignedAddress + 4, data[1], 0b1111);
        break;
        case 8:
            memoryContents.write(alignedAddress, data[0], 0b1111);
            memoryContents.write(alignedAddress + 4, data[1], 0b1111);
            memoryContents.write(alignedAddress + 8, data[2], 0b1111);
            memoryContents.write(alignedAddress + 16, data[3], 0b1111);
        break;

    }

    return sv_1;
}

void memory_init(std::string filename) {
    using namespace std::placeholders;

    memoryContents = Memory32();

    std::function<void(uint32_t, uint32_t, const uint8_t*)> f =
        std::bind(&Memory32::write_block, &memoryContents, _1, _2, _3);

    elfLoader loader = elfLoader(f);
    loader(filename);
}

static bool debug_read = false;

void memory_enable_read_debug() {
    debug_read = true;
}

// *** Memory module ***

bool Memory32::write(const uint32_t addr, const uint32_t &data,
                     const uint32_t &mask) {
    assert((addr & 0x3) == 0);
    if (addr_max != 0 && addr >= addr_max)
        return false;

    uint32_t data_m = mem[addr];
    for (int i = 0; i < 4; i++) {
        if ((mask & (1 << i))) { // write when mask[i] is 1'b1
            data_m = (data_m & ~(0xff << i * 8)) | (data & (0xff << i * 8));
        }
    }
    mem[addr] = data_m;

    if (debug_read) printf("MemoryModel::read Address = 0x%x, data = 0x%x\n", addr, data_m);
    return true;
}

void Memory32::write_block(uint32_t addr, uint32_t size, const uint8_t* buf) {
    uint32_t burst_size = 4;
    uint32_t mask = (1 << burst_size) - 1;

    // prologue
    if(uint32_t offset = addr%4) {
        uint32_t m_size = 4 - offset;
        mask >>= (m_size > size) ? m_size - size : 0;
        m_size = (m_size > size) ? size : m_size;
        mask <<= offset;
        write(addr - offset, *((uint32_t*)(buf - offset)), mask);
        size -= m_size;
        buf += m_size;
        addr += m_size;
    }

    // block write
    mask = (1 << burst_size) - 1;
    while(size >= burst_size) {
        write(addr, *((uint32_t*)(buf)), mask);
        size -= burst_size;
        buf += burst_size;
        addr += burst_size;
    }

    // epilogue
    if(size) {
        write(addr, *((uint32_t*)(buf)), (1 << size) - 1);
    }
}

bool Memory32::read(const uint32_t addr, uint32_t &data) {
    assert((addr & 0x3) == 0);
    if (addr_max != 0 && addr >= addr_max || !mem.count(addr)) {
        if (debug_read) printf("WARN: Memory access outside of range: 0x%8x\n", addr);
        return false;
    }

    data = mem[addr];
    if (debug_read) printf("MemoryModel::read Address = 0x%x, data = 0x%x\n", addr, data);

    return true;
}