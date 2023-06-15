#include "dpi_perfect_memory.h"

#include <map>
#include <cstdint>
#include <cassert>
#include <iostream>
#include <unistd.h>

#include "loadelf.hpp"
#include "globals.h"

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
static uint64_t tohostAddr;
static uint64_t fromhostAddr;
static std::map<std::string, uint64_t> symbols;
static std::map<uint64_t, std::string> reverseSymbols;

void memory_read(const svBitVecVal *addr, svBitVecVal *data) {
    uint32_t baseAddress = addr[0];

    /*if (baseAddress ==  ((uint32_t) fromhostAddr)) {
        printf("Fromhost!!!\n");
    }*/

    for (unsigned int i = 0; i < BUS_WIDTH / 32; i++) {
        uint32_t dataRead;
        memoryContents.read(baseAddress + i * 4, dataRead);
        data[i] = dataRead;
    }
}

void tohost(unsigned int id, unsigned long long data);

void memory_write(const svBitVecVal *addr, const svBitVecVal *byte_enable, const svBitVecVal *data) {
    uint32_t baseAddress = addr[0];

    if (baseAddress == ((uint32_t) tohostAddr)) {
        //printf("Tohost!!!\n");
        tohost(0, ((uint64_t) data[1]) << 32 | data[0]);
        return;
    }

    for (unsigned int i = 0; i < (BUS_WIDTH/32); i++) {
        if (byte_enable[0] & (0b1111 << (i*4))) {
            memoryContents.write(baseAddress + i*4, data[i], (byte_enable[0] >> (i*4)) & 0b1111);
        }
    }
}

 void memory_amo(const svBitVecVal *addr_ptr, const svBitVecVal *size_ptr, const svBitVecVal *amo_op_ptr, const svBitVecVal *data_ptr, svBitVecVal *result_ptr) {
    uint32_t addr = addr_ptr[0];
    uint32_t size = size_ptr[0];
    uint32_t amo_op = amo_op_ptr[0];

    bool is_double = size == 3;

    uint32_t offset = (addr >> (is_double ? 3 : 2)) % (BUS_WIDTH/32);

    // Read old values
    for (unsigned int i = 0; i < BUS_WIDTH / 32; i++) {
        uint32_t dataRead;
        memoryContents.read(addr + i * 4, dataRead);
        result_ptr[i] = dataRead;
    }

    // Get the values from memory and the core
    uint64_t mem_val, core_val, result;

    if (is_double) {
        uint32_t data_hi, data_lo;
        memoryContents.read(addr, data_lo);
        memoryContents.read(addr + 4, data_hi);

        mem_val = ((uint64_t) data_hi << 32) | data_lo;
        core_val = ((uint64_t) data_ptr[offset + 1] << 32) | data_ptr[offset];
    } else {
        uint32_t data_lo;
        memoryContents.read(addr, data_lo);

        mem_val = (int32_t) data_lo;
        core_val = (int32_t) data_ptr[offset];
    }

    // Perform operation
    switch(amo_op) {
        case 0b0000: result = mem_val + core_val; break;  //HPDCACHE_MEM_ATOMIC_ADD
        case 0b0001: result = mem_val & ~core_val; break; //HPDCACHE_MEM_ATOMIC_CLR
        case 0b0010: result = mem_val | core_val; break;  //HPDCACHE_MEM_ATOMIC_SET
        case 0b0011: result = mem_val ^ core_val; break;  //HPDCACHE_MEM_ATOMIC_EOR
        case 0b0100: result = mem_val > core_val ? mem_val : core_val; break; //HPDCACHE_MEM_ATOMIC_SMAX
        case 0b0101: result = mem_val < core_val ? mem_val : core_val; break; //HPDCACHE_MEM_ATOMIC_SMIN
        case 0b0110: result = (unsigned) mem_val > (unsigned) core_val ? mem_val : core_val; break; //HPDCACHE_MEM_ATOMIC_UMAX
        case 0b0111: result = (unsigned) mem_val < (unsigned) core_val ? mem_val : core_val; break; //HPDCACHE_MEM_ATOMIC_UMIN
        case 0b1000: result = core_val; break; //HPDCACHE_MEM_ATOMIC_SWAP
        //  Reserved           = 4'b1001,
        //  Reserved           = 4'b1010,
        //  Reserved           = 4'b1011,
        case 0b1100: result = mem_val; break;  //HPDCACHE_MEM_ATOMIC_LDEX
        case 0b1101: result = core_val; break; //HPDCACHE_MEM_ATOMIC_STEX
    }

    // Write contents to memory
    if (is_double) {
        memoryContents.write(addr, result & 0xffffffff, 0b1111);
        memoryContents.write(addr + 4, result >> 32, 0b1111);
    } else {
        memoryContents.write(addr, result & 0xffffffff, 0b1111);
    }
 }

void memory_init(std::string filename) {
    using namespace std::placeholders;

    memoryContents = Memory32();

    std::function<void(uint32_t, uint32_t, const uint8_t*)> f =
        std::bind(&Memory32::write_block, &memoryContents, _1, _2, _3);

    elfLoader loader = elfLoader(f);
    symbols = loader(filename);

    for (const auto& kv : symbols)
        reverseSymbols[kv.second] = kv.first;
        
    tohostAddr = symbols["tohost"];
    fromhostAddr = symbols["fromhost"];
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

    if (debug_read) printf("MemoryModel::write Address = 0x%x, data = 0x%x\n", addr, data_m);
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
        data = 0;
        return false;
    }

    data = mem[addr];
    if (debug_read) printf("MemoryModel::read Address = 0x%x, data = 0x%x\n", addr, data);

    return true;
}


// Commands definition
#define SYS_write 64

void tohost(unsigned int id, unsigned long long data) {
  if(data & 1) {
    uint64_t payload = data << 16 >>16;
    // test pass/fail
    if(payload != 1) {
      std::cout << "Core " << id << " exit with error code " << (payload >> 1) << std::endl;
      exit_code = payload >> 1;
      exit_delay = 1;
    }
    else {
      std::cout << "Run finished correctly" << std::endl;
      exit_code = 0;
      exit_delay = 1;
    }
    std::cout << "Run time is : " << main_time << std::endl;
  } else {
    uint64_t magicmem[8];
    uint32_t upper, lower;

    for (unsigned int i = 0; i < 8; i++) {
        memoryContents.read((data + i*8), lower);
        memoryContents.read((data + i*8) + 4, upper);
        magicmem[i] = ((uint64_t) upper) << 32 | lower;
    }

    switch (magicmem[0]) {
        case SYS_write:
        {
            uint64_t length = magicmem[3];
            char buf[length];
            for (unsigned int i = 0; i < length; i++) {
                uint32_t data;
                memoryContents.read(magicmem[2] + (i & ~0b11), data);
                buf[i] = data >> ((i%4) * 8);
            }
            uint64_t result = write(magicmem[1], buf, length);
            memoryContents.write(fromhostAddr, result & 0xffffffff, 0b1111);
            memoryContents.write(fromhostAddr + 4, (result >> 32) & 0xffffffff, 0b1111);
            break;
        }
        default:
            std::cerr << "Unknown tohost syscall " << std::hex << magicmem[0] << std::endl;
    }
  }
}

std::string memory_symbol_from_addr(uint64_t addr) {
    auto symbol = reverseSymbols.find(addr);

    return symbol == reverseSymbols.end() ? std::string("") : symbol->second;
}
