#include "dpi_commit_log.h"
#include "dpi_perfect_memory.h"
#include "riscv/disasm.h"
#include <cassert>
#include <stack>
#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>

#define HEX_PC( x ) "0x" << std::right << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define HEX_INST( x ) "0x" << std::right << std::setw(8) << std::setfill('0') << std::hex << (long)( x )
#define HEX_DATA( x ) "0x" << std::right << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define HEX_ADDR( x ) "0x" << std::right << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define HEX_WORD( x ) "0x" << std::right << std::setw(8) << std::setfill('0') << std::hex << (uint32_t)( x )
#define HEX_HALF( x ) "0x" << std::right << std::setw(4) << std::setfill('0') << std::hex << (uint16_t)( x )
#define HEX_BYTE( x ) "0x" << std::right << std::setw(2) << std::setfill('0') << std::hex << (long)( ( x ) & 0xff )
#define DEC_DATA( x )  std::dec << (long)( x )
#define HEX_VDATA( x ) std::right << std::setw(8) << std::setfill('0') << std::hex << (long)( x )
#define DEC_DST( x ) "x" << std::left << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_FDST( x ) "f" << std::left << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_VDST( x ) "v" << std::left << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_PRIV( x ) std::setw(1) << std::dec << (long)( x )
#define DEC_CSR( x ) "c" << std::right << std::setw(3) << std::dec << (long)( x )

// Global objects
CommitLog *commitLog;

// *** SystemVerilog DPI ***

void commit_log_init(const char* logfile){
    commitLog = new CommitLog(logfile);
}

void commit_log (const commit_data_t *commit_data){
    commitLog->dump_file(commit_data);
}

// *** End of SystemVerilog DPI ***

CommitLog::CommitLog(const char *logfile) {
    signatureFileName = logfile;
    signatureFile.open(signatureFileName, std::ios::out);
    signature = (uint64_t*) calloc(32,sizeof(uint64_t));

    isa = new isa_parser_t("rv64imaf", "msu");
    disassembler = new disassembler_t(isa);
}

std::vector<std::pair<uint64_t, uint64_t>> csr_changes;

void csr_change(unsigned long long addr, unsigned long long value) {
    csr_changes.push_back(std::make_pair(addr, value));
}

std::stack<uint64_t> amo_writes;

void commit_log_dump_amo_write(const uint32_t baseAddress,  const uint64_t data) {
    amo_writes.push(data);
}

void CommitLog::dump_file(const commit_data_t *commit_data){
    //DPI data unpadding
    uint64_t scalar_data = (uint64_t)commit_data->data[1] << 32 | (commit_data->data[0]);

    if(commit_data->reg_wr_valid || commit_data->freg_wr_valid) {
        signature[commit_data->dst] = scalar_data;
    }

    // file dumping

    std::string symbol = memory_symbol_from_addr(commit_data->pc);
    if (!symbol.empty()) signatureFile << "core   0: >>>>  " << symbol << std::endl;

    if ( commit_data->xcpt_cause != CAUSE_INSTR_PAGE_FAULT || !commit_data->xcpt){  // Neiel-leyva
        signatureFile << "core   0: " << HEX_PC(commit_data->pc) << " (" << HEX_INST(commit_data->inst) << ") " << disassembler->disassemble(insn_t(commit_data->inst)) << "\n";
    }

    //exceptions
    if (commit_data->xcpt) {
        signatureFile.close();
        if (commit_data->inst == 0x9f019073) dump_xcpt(commit_data->xcpt_cause, commit_data->pc, 0); //Write tohost, 0 in tval
        else dump_xcpt(commit_data->xcpt_cause, commit_data->pc, commit_data->csr_tval);
        signatureFile.open(signatureFileName, std::ios::out | std::ios::app);
    } else if (commit_data->csr_xcpt) {
        signatureFile.close();
        // TODO: DIRTY HACK! tval should be set properly in the core!
        dump_xcpt(commit_data->csr_xcpt_cause, commit_data->pc, commit_data->csr_tval ? commit_data->csr_tval : commit_data->inst);
        csr_changes.clear();
        signatureFile.open(signatureFileName, std::ios::out | std::ios::app);
    } else {
        int opcode = commit_data->inst & 0x7f;
        int func3 = (commit_data->inst >> 12) & 0x7;
        int func6 = (commit_data->inst >> 26) & 0x3f;
        int func7 = (commit_data->inst >> 25) & 0x5f;
        int is_vext = 0;
        int is_vse = 0;
        if (opcode == 0x57 && func3 == 0x2 && func6 == 0x0c) is_vext = 1;
        if (opcode == 0x27 && func3 == 0x7) is_vse = 1;

        signed long long signedAddr = commit_data->mem_addr;
        signedAddr = signedAddr << 24;
        signedAddr = signedAddr >> 24;

        signatureFile << "core   0: " << DEC_PRIV(commit_data->csr_priv_lvl) << " " << HEX_PC(commit_data->pc) << " (" << HEX_INST(commit_data->inst) << ")";

        // Print fflags
        bool fflags_found = false;
        for (auto it = csr_changes.begin(); it != csr_changes.end();) {
            uint64_t csr = (*it).first;
            uint64_t value = (*it).second;

            if (csr == 0x001 && commit_data->fflags_wr_valid) { // CSR is fflags
                signatureFile << " c1_fflags " << HEX_DATA(value);
                last_fflags = value;
                fflags_found = true;
                it = csr_changes.erase(it); // Remove it so it isn't printed later
            } else {
                ++it;
            }
        }

        // In the case two back-to-back floating point operations are executed
        // in the same cycle, both setting the fflags, the later one will have
        // the flags active but they won't be in the list anymore because the
        // first instruction will have removed it.
        if (commit_data->fflags_wr_valid && !fflags_found) {
            signatureFile << " c1_fflags " << HEX_DATA(last_fflags);
        }

        // Print register writebacks
        if (commit_data->reg_wr_valid) {
            signatureFile << " " << DEC_DST(commit_data->dst) << " " << HEX_DATA(signature[commit_data->dst]);
        }
        if (commit_data->freg_wr_valid) {
            signatureFile << " " << DEC_FDST(commit_data->dst) << " " << HEX_DATA(signature[commit_data->dst]);
        }
        if (commit_data->vreg_wr_valid || is_vext || is_vse) {
            switch (commit_data->sew) {
                case 0:
                    signatureFile << " e8 m1 l16";
                    break;
                case 1:
                    signatureFile << " e16 m1 l8";
                    break;
                case 2:
                    signatureFile << " e32 m1 l4";
                    break;
                case 3:
                    signatureFile << " e64 m1 l2";
                    break;
            }
            if (commit_data->vreg_wr_valid) {
                signatureFile << " " << DEC_VDST(commit_data->vdst) << " 0x";
                for (int i = (VVLEN/32)-1; i >= 0; --i) {
                    signatureFile << HEX_VDATA(commit_data->data[i]);
                }
            }
        }

        // Print CSR changes
        for (auto& change : csr_changes) {
            uint64_t csr = change.first;
            uint64_t value = change.second;
            switch(csr) {
                case 0x001: break; // Ignore fflags
                case 0x300: // Fixes for RISC-V Privilege ISA 1.11 (from core) to 1.12 (from Spike simulator)
                    signatureFile << " " << DEC_CSR(csr) << "_" << csr_name(csr) << " " << HEX_DATA(value & ~0x600);
                    break;
                case 0x003: // Spike prints changes to FCSR individually by bit fields
                    signatureFile << " c1_fflags " << HEX_DATA(change.second & 0b11111);
                    signatureFile << " c2_frm " << HEX_DATA((change.second >> 5) & 0b111);
                    break;
                default:
                    signatureFile << " " << DEC_CSR(csr) << "_" << csr_name(csr) << " " << HEX_DATA(value);
                    break;
            }
        }

        // Delete all CSR changes except for fflags. This is done because the
        // next instruction commited in the same cycle might have produced the
        // change in the fflags, and so mustn't be deleted. They will be deleted
        // once that instruction performs the dump.
        for (auto it = csr_changes.begin(); it != csr_changes.end();) {
            uint64_t csr = (*it).first;
            uint64_t value = (*it).second;

            if (csr != 0x001) it = csr_changes.erase(it);
            else ++it;
        }

        // Print memory operations
        switch (commit_data->mem_type) {
            default:
            case 0:
                break;
            case 1: // Load
                signatureFile << " mem " << HEX_DATA(signedAddr);
                break;
            case 2: // Store
                signatureFile << " mem " << HEX_DATA(signedAddr) << " ";
                switch (func3) {
                    case 0b000: 
                    case 0b100:
                        signatureFile << HEX_BYTE(scalar_data);
                        break;
                    case 0b001:
                    case 0b101:
                        signatureFile << HEX_HALF(scalar_data);
                        break;
                    case 0b010:
                        signatureFile << HEX_WORD(scalar_data);
                        break;
                    default:
                        signatureFile << HEX_DATA(scalar_data);
                        break;
                }
                break;
            case 3: // AMO
                signatureFile << " mem " << HEX_DATA(signedAddr);
                uint64_t amo = amo_writes.top();
                signatureFile << " mem " << HEX_DATA(signedAddr) << " ";
                if (func3 == 0b010) signatureFile << HEX_WORD((uint32_t) amo);
                else signatureFile << HEX_DATA(amo);
                amo_writes.pop();
                break;
        }
	    signatureFile << "\n";
    }
    
    signatureFile.flush();
}

void CommitLog::dump_xcpt(uint64_t xcpt_cause, uint64_t epc, uint64_t tval) {
    signatureFile.open(signatureFileName, std::ios::out | std::ios::app);
    signatureFile << "core   0: exception ";
    switch (xcpt_cause) {
        case CAUSE_MISALIGNED_FETCH:
            signatureFile << "trap_misaligned_fetch";
            break;
        case CAUSE_FAULT_FETCH:
            signatureFile << "trap_fault_fetch";
            break;
        case CAUSE_ILLEGAL_INSTRUCTION:
            signatureFile << "trap_illegal_instruction";
            break;
        case CAUSE_BREAKPOINT:
            signatureFile << "trap_breakpoint";
            break;
        case CAUSE_MISALIGNED_LOAD:
            signatureFile << "trap_load_address_misaligned";
            break;
        case CAUSE_FAULT_LOAD:
            signatureFile << "trap_fault_load";
            break;
        case CAUSE_MISALIGNED_STORE:
            signatureFile << "trap_store_address_misaligned";
            break;
        case CAUSE_FAULT_STORE:
            signatureFile << "trap_fault_store";
            break;
        case CAUSE_USER_ECALL:
            signatureFile << "trap_user_ecall";
            break;
        case CAUSE_SUPERVISOR_ECALL:
            signatureFile << "trap_supervisor_ecall";
            break;
        case CAUSE_MACHINE_ECALL:
            signatureFile << "trap_machine_ecall";
            break;
        case CAUSE_INSTR_PAGE_FAULT:
            //signatureFile << "trap_instruction_ecall";
            signatureFile << "trap_instruction_page_fault"; // Neiel-leyva
            break;
        case CAUSE_LD_PAGE_FAULT:
            signatureFile << "trap_load_page_fault";
            break;
        case CAUSE_ST_AMO_PAGE_FAULT:
            signatureFile << "trap_store_page_fault";
            break;
        default:
            signatureFile << xcpt_cause;
    }
    signatureFile << ", epc " << HEX_PC(epc) << "\n";

    //If it's not an ecall, print tval
    if (xcpt_cause != CAUSE_USER_ECALL && xcpt_cause != CAUSE_SUPERVISOR_ECALL && xcpt_cause != CAUSE_MACHINE_ECALL) {
        signatureFile << "core   0:           tval " << HEX_DATA(tval) << "\n";
    }

    signatureFile.close();
}