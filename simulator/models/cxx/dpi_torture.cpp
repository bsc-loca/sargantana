#include "dpi_torture.h"
#include "dpi_perfect_memory.h"
#include "riscv/disasm.h"
#include <cassert>
#include <stack>
#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#ifdef COSIM
#include "spike.h"
#endif

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
tortureSignature *torture_signature;

#ifdef COSIM
spike_wrapper *spike;
core_state_t *core_state;
#endif

// Global Variables
uint64_t last_PC=0, last_inst=0, last_data=0, last_dst=0;
int misscnt = 0;
unsigned long long cycl = 0;
int timer_int = 0;
uint64_t last_commit_deadlock=0, last_PC_deadlock = 0;

void check_deadlock (unsigned long long cycles, unsigned long long PC, unsigned long long commit_valid){
    signed long long signedPC = PC;
    signedPC = signedPC << 24;
    signedPC = signedPC >> 24;
    if (commit_valid && (last_PC_deadlock != PC)) {
        last_PC_deadlock = signedPC;
        last_commit_deadlock = cycles;
    } else if (cycles > (last_commit_deadlock + 100000)){
        std::cout << "Deadlock with last valid commit PC: " << HEX_PC(last_PC_deadlock) << " and cycle: " << DEC_DATA(last_commit_deadlock);
        last_commit_deadlock = cycles;
    } 
}

#ifdef COSIM
void spike_setup(const char* binaryFileName) {
    int nargs = 3;

    char** args = (char**)malloc((nargs+1)*sizeof(char*));

    args[0] = (char*)"./spike";
    args[1] = (char*)"--isa=RV64IMAFD";
    args[2] = (char*)binaryFileName;
    args[3] = (char*)NULL;

    spike = new spike_wrapper();
    spike->setup(nargs, (const char**)args);
    
    core_state = (core_state_t*) malloc(sizeof(core_state_t));

}

void stop_execution() {
    free(spike);
}

void start_execution() {
    spike->start_execution();
    
    processor_t* core = spike->s->get_core(0);
    state_t* p_state = core->get_state();

    while (p_state->pc < 0x80000000) {
        spike->s->step(1);
        p_state = core->get_state(); // could be remove, it is a pointer...
    }
    p_state->XPR.write(11, 0x180); // match core register initialization
}

/*void step(core_state_t* core_state) {
    spike->step(core_state);
}*/

int run_and_inject(uint32_t instr, core_state_t* core_state){
    return spike->run_and_inject(instr, core_state);
}

int get_memory_data(uint64_t* data, uint64_t direction){
    return spike->load_uint(data,direction);
}
#endif

// System Verilog DPI
void torture_dump (unsigned long long cycles, const commit_data_t *commit_data){
    
    //std::cout << data0 << " " << data1 << " " << data2 << " " << data3 << std::endl;
    //std::cout << data << std::endl;
    uint64_t scalar_data = ((uint64_t)(commit_data->data[1]) << 32) | (commit_data->data[0]);
    uint64_t max_miss = torture_signature->get_max_miss();
        
    //Exceptions can come from the core (xcpt) or from the csrs (csr_xcpt)
    //And cannot happen both at once, so a simple OR suffices
    unsigned long long var_xcpt = commit_data->xcpt | commit_data->csr_xcpt;
    unsigned long long var_xcpt_cause = commit_data->xcpt_cause | commit_data->csr_xcpt_cause;
    //We need to extend the PC sign
    signed long long signedPC = commit_data->pc;
    signedPC = signedPC << 24;
    signedPC = signedPC >> 24;
    
    cycl = cycles;

    if(torture_signature->dump_check()){
        if(commit_data->reg_wr_valid || commit_data->freg_wr_valid) {
            torture_signature->update_signature(commit_data->dst, scalar_data);
        }
        if((last_PC == signedPC) && (last_inst == commit_data->inst) && (last_dst == commit_data->dst) && (last_data == scalar_data))
        {

        }else{

            if (commit_data->inst == 0x00000073) { //ecall
                var_xcpt = 1;
                if (commit_data->csr_priv_lvl == 0) var_xcpt_cause = CAUSE_USER_ECALL;
                else if (commit_data->csr_priv_lvl == 1) var_xcpt_cause = CAUSE_SUPERVISOR_ECALL;
                //else if (csr_priv_lvl == 3) var_xcpt_cause = CAUSE_MACHINE_ECALL;
            }
            else if (commit_data->inst == 0x00100073) { //ebreak
                var_xcpt = 1;
                var_xcpt_cause = CAUSE_BREAKPOINT;
            }
            else if (commit_data->inst == 0x9f019073) { //hardcoded tohost exception
                var_xcpt = 1;
                var_xcpt_cause = CAUSE_ILLEGAL_INSTRUCTION;
            }

            last_PC = signedPC;
            last_inst = commit_data->inst;
            last_dst = commit_data->dst;
            last_data = scalar_data;

#ifdef COSIM
            if (PC > 0x00000110) { 
                if (inst == 0x9f051073) run_and_inject(0x00000013, core_state); // csr tohost, inject NOP
                else if (inst >= 0xc0102073 && inst <= 0xc0102ff3) { // rdtime instruction, inject NOP and result
                    run_and_inject(0x00000013, core_state);
                    processor_t* core = spike->s->get_core(0);
                    state_t* p_state = core->get_state();
                    p_state->XPR.write(dst, scalar_data);
                }
                else if (signedPC == 0x8000577c || signedPC == 0x80005780 || signedPC == 0x800057e4 || signedPC == 0x800057ec
                        || signedPC == 0x80005810 || signedPC == 0x80005814) run_and_inject(0x00000013, core_state); // store in 0x40170000 (drac_timer)
                else {
                    int opcode = inst & 0x7f;
                    int func5 = (inst >> 27) & 0x1f;
                    int func3 = (inst >> 12) & 0x7;
                    int rs1 = (inst >> 15) & 0x1f;
                    int csr = (inst >> 20) & 0xfff;
                     if (var_xcpt && (var_xcpt_cause == 0x8000000000000007)) { // inject timer interrupt to spike
//                         std::cout << "timer interrupt" << std::endl;
                        processor_t* core = spike->s->get_core(0);
                        state_t* p_state = core->get_state();
                        p_state->mip |= (1 << (var_xcpt_cause & 0x7)); // MIP_MTIP
                    }
                    if (signedPC == 0x800032d0) { // clear machine timer interrupt pending bit when we enable the interrupt again
                        processor_t* core = spike->s->get_core(0);
                        state_t* p_state = core->get_state();
                        p_state->mip &= ~(1 << 7);
                    }
//                     std::cout << "Inst: " << HEX_INST(inst) << std::endl;
                    run_and_inject(inst, core_state);
                    processor_t* spike_core = spike->s->get_core(0);
                    state_t* spike_state = spike_core->get_state();
//                     std::cout << "Spike -------------------" << std::endl;
//                     std::cout << "Inst: " << HEX_INST(core_state->ins) << std::endl;
                    /*if (cycles > 280000000) {
                        std::cout << "Core PC: " << HEX_PC(signedPC) << "Inst: " << HEX_INST(inst) << " Reg: " << dst << " Data: " << HEX_DATA(scalar_data) << std::endl;
                        std::cout << "Spike PC: " << HEX_PC(core_state->pc) << " Inst: " << HEX_INST(core_state->ins) << " Reg: " << core_state->dst_num << " Data: " 
                            << HEX_DATA(core_state->dst_value) << " Addr: " << core_state->mem_addr << std::endl; //" Mip: " << spike_state->mip 
                    }*/
             //        << " Mie: " << std::endl;
//                     std::cout << "--------------------------------------------------" << std::endl;
                    if (func3 == 0x2 && opcode == 0x73 && csr == 0x300) { // csrr mstatus, reserved bits
                        processor_t* core = spike->s->get_core(0);
                        state_t* p_state = core->get_state();
                        p_state->XPR.write(dst, scalar_data | 0x600);
                        scalar_data = scalar_data & 0xfffffffffffff9ff;
                    }
                    if (signedPC == 0x8000d338) { // csr mstatus
                        processor_t* core = spike->s->get_core(0);
                        state_t* p_state = core->get_state();
                        p_state->XPR.write(22, 0x8000000a00006600);
                    }
                    if (func3 == 0x2 && opcode == 0x73 && rs1 == 0x0 && csr == 0x3b0) { // change read value from csr pmpaddr0 to 0
                        processor_t* core = spike->s->get_core(0);
                        state_t* p_state = core->get_state();
                        p_state->XPR.write(16, 0x0);
                    }
                    else if (opcode == 0x2f && (func5 == 0x2 || func5 == 0x3)) { // LR/SC write the same result to spike to avoid desync
                        processor_t* core = spike->s->get_core(0);
                        state_t* p_state = core->get_state();
                        p_state->XPR.write(dst, scalar_data);
                        if (func5 == 0x3 && scalar_data == 0 && core_state->dst_value != 0) {
//                             std::cout << "inject store conditional " << core_state->src1_value << " " << core_state->src2_value << std::endl;
                            mmu_t* p_mmu = core->get_mmu();
                            if (func3 == 0x2) { 
                                p_mmu->store_uint32(core_state->src1_value, core_state->src2_value);
                            }
                            else {
                                p_mmu->store_uint64(core_state->src1_value, core_state->src2_value);
                            }
                        }
                    }
                    else if ((signedPC != core_state->pc || inst != core_state->ins || dst != core_state->dst_num || ((reg_wr_valid || freg_wr_valid) && scalar_data != core_state->dst_value)) && 
                        !(var_xcpt && (var_xcpt_cause == 0x8000000000000007 || var_xcpt_cause == 0x8000000000000005)) && max_miss != 0) {
                        torture_signature->dump_file(signedPC, inst, dst, fdst, vdst, reg_wr_valid, freg_wr_valid, vreg_wr_valid, var_xcpt, var_xcpt_cause, data0,data1,data2,data3, sew, csr_priv_lvl, csr_rw_data, csr_tval);
                        torture_signature->dump_spike(core_state->pc, core_state->ins, core_state->dst_num, core_state->dst_value);
                        ++misscnt;
                        torture_signature->set_first_missmatch(true);
                        if (misscnt == max_miss) {
                            stop_execution();
                            torture_signature->disable();
                        }
                    }
                }
            }
#else
        torture_signature->dump_file(cycles, commit_data);
#endif
        }
    }

    if(torture_signature->get_debug_addr() != 0){
        if (torture_signature->get_debug_addr() == signedPC){
            std::cout << "Debug PC: " << HEX_PC(signedPC) << " executed on cycle: " << DEC_DATA(cycles);
        }
    }
}

std::vector<std::pair<uint64_t, uint64_t>> csr_changes;

void csr_change(unsigned long long addr, unsigned long long value) {
    csr_changes.push_back(std::make_pair(addr, value));
}

std::stack<uint64_t> amo_writes;

void torture_dump_amo_write(const uint32_t baseAddress,  const uint64_t data) {
    amo_writes.push(data);
}

#ifndef INCISIVE_SIMULATION
    void torture_signature_init(const char* binaryFileName){
        torture_signature = new tortureSignature;
        #ifdef COSIM
            spike_setup(binaryFileName);
            start_execution();
        #endif
    }
#else
    void torture_signature_init(){
        torture_signature = new tortureSignature;
    }
#endif


// Torture Signature
void tortureSignature::disable()
{
    dump_valid = false;
}

void tortureSignature::set_dump_file_name(std::string name)
{
    signatureFileName = name;
}

void tortureSignature::set_debug_addr(std::string addr)
{
    debug_addr = std::stoul(addr, nullptr, 16);
}

void tortureSignature::set_max_miss(std::string miss)
{
    max_miss = std::stoul(miss, nullptr, 16);
}

void tortureSignature::set_first_missmatch(bool conf)
{
    first_missmatch = conf;
}

bool tortureSignature::dump_check()
{
    return dump_valid;
}

uint64_t tortureSignature::get_debug_addr()
{
    return debug_addr;
}

uint64_t tortureSignature::get_max_miss()
{
    return max_miss;
}

bool tortureSignature::get_first_missmatch()
{
    return first_missmatch;
}

void tortureSignature::clear_output()
{
    signatureFile.open(signatureFileName, std::ios::out);
    signatureFile.close();
}

void tortureSignature::update_signature(uint64_t dst, uint64_t data){
    signature[dst] = data;
}

uint64_t last_fflags;

void tortureSignature::dump_file(unsigned long long cycles, const commit_data_t *commit_data){

    //DPI data unpadding
    uint64_t scalar_data = (uint64_t)commit_data->data[1] << 32 | (commit_data->data[0]);

    // file dumping
    
    signatureFile.open(signatureFileName, std::ios::out | std::ios::app);

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
#ifdef COSIM
        signatureFile << " Cycles " << cycl << "\n";
#else
	signatureFile << "\n";
#endif
    }
    signatureFile.close();
}

void tortureSignature::dump_xcpt(uint64_t xcpt_cause, uint64_t epc, uint64_t tval) {
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
#ifdef COSIM
    signatureFile << " Cycles " << cycl << "\n";
#endif

    signatureFile.close();
}

void tortureSignature::dump_spike(uint64_t PC, uint64_t inst, uint64_t dst, uint64_t dst_value) {
    signatureFile.open(signatureFileName, std::ios::out | std::ios::app);
    signatureFile << "spike: " << HEX_PC(PC) << " (" << HEX_INST(inst) << ") " << disassembler->disassemble(insn_t(inst)) << "\n";
    signatureFile << " " << DEC_DST(dst) << " " << HEX_DATA(dst_value) << "\n";
    signatureFile.close();
}
    
