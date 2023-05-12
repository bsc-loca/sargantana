#include "dpi_torture.h"
#include <iostream>
#include <fstream>
#include <iomanip>
#include <string>
#ifdef COSIM
#include "spike.h"
#endif

#define HEX_PC( x ) "0x" << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define HEX_INST( x ) "0x" << std::setw(8) << std::setfill('0') << std::hex << (long)( x )
#define HEX_DATA( x ) "0x" << std::setw(16) << std::setfill('0') << std::hex << (long)( x )
#define DEC_DATA( x )  std::dec << (long)( x )
#define HEX_VDATA( x ) std::setw(8) << std::setfill('0') << std::hex << (long)( x )
#define DEC_DST( x ) "x" << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_FDST( x ) "f" << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_VDST( x ) "v" << std::setw(2) << std::setfill(' ') << std::dec << (long)( x )
#define DEC_PRIV( x ) std::setw(1) << std::dec << (long)( x )

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
void torture_dump (unsigned long long cycles, unsigned long long PC, unsigned long long inst, unsigned long long dst, unsigned long long fdst,unsigned long long vdst,
                   unsigned long long reg_wr_valid, unsigned long long freg_wr_valid, unsigned long long vreg_wr_valid, 
                   unsigned int data0, unsigned int data1, unsigned int data2, unsigned int data3,
                   unsigned long long sew, unsigned long long xcpt, unsigned long long xcpt_cause, unsigned long long csr_priv_lvl,
                   unsigned long long csr_rw_data, unsigned long long csr_xcpt, unsigned long long csr_xcpt_cause, unsigned long long csr_tval){
    
    //std::cout << data0 << " " << data1 << " " << data2 << " " << data3 << std::endl;
    //std::cout << data << std::endl;
    uint64_t scalar_data = ((uint64_t)(data1) << 32) | (data0);
    uint64_t max_miss = torture_signature->get_max_miss();
        
    //Exceptions can come from the core (xcpt) or from the csrs (csr_xcpt)
    //And cannot happen both at once, so a simple OR suffices
    unsigned long long var_xcpt = xcpt | csr_xcpt;
    unsigned long long var_xcpt_cause = xcpt_cause | csr_xcpt_cause;
    //We need to extend the PC sign
    signed long long signedPC = PC;
    signedPC = signedPC << 24;
    signedPC = signedPC >> 24;
    
    cycl = cycles;

    if(torture_signature->dump_check()){
        if(reg_wr_valid || freg_wr_valid) {
            torture_signature->update_signature(dst, scalar_data);
        }
        if((last_PC == signedPC) && (last_inst == inst) && (last_dst == dst) && (last_data == scalar_data))
        {

        }else{

            if (inst == 0x00000073) { //ecall
                var_xcpt = 1;
                if (csr_priv_lvl == 0) var_xcpt_cause = CAUSE_USER_ECALL;
                else if (csr_priv_lvl == 1) var_xcpt_cause = CAUSE_SUPERVISOR_ECALL;
                //else if (csr_priv_lvl == 3) var_xcpt_cause = CAUSE_MACHINE_ECALL;
            }
            else if (inst == 0x00100073) { //ebreak
                var_xcpt = 1;
                var_xcpt_cause = CAUSE_BREAKPOINT;
            }
            else if (inst == 0x9f019073) { //hardcoded tohost exception
                var_xcpt = 1;
                var_xcpt_cause = CAUSE_ILLEGAL_INSTRUCTION;
            }

            last_PC = signedPC;
            last_inst = inst;
            last_dst = dst;
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
        torture_signature->dump_file(signedPC, inst, dst, fdst, vdst, reg_wr_valid, freg_wr_valid, vreg_wr_valid, var_xcpt, var_xcpt_cause, data0,data1,data2,data3, sew, csr_priv_lvl, csr_rw_data, csr_tval);
#endif
        }
    }

    if(torture_signature->get_debug_addr() != 0){
        if (torture_signature->get_debug_addr() == signedPC){
            std::cout << "Debug PC: " << HEX_PC(signedPC) << " executed on cycle: " << DEC_DATA(cycles);
        }
    }
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

void tortureSignature::dump_file(uint64_t PC, uint64_t inst, uint64_t dst, uint64_t fdst, uint64_t vdst, uint64_t reg_wr_valid, uint64_t freg_wr_valid,
                                uint64_t vreg_wr_valid, uint64_t xcpt, uint64_t xcpt_cause,
                                uint32_t data0, uint32_t data1, uint32_t data2, uint32_t data3,
                                uint64_t sew, uint64_t csr_priv_lvl, uint64_t csr_rw_data, uint64_t csr_tval){

    //DPI data unpadding
    uint64_t scalar_data = (uint64_t)data1 << 32 | (data0);
    uint32_t data_int[VVLEN/32];
    //for (int i = 0; i < VVLEN/32; ++i) {
        data_int[0]   = data0;
        data_int[1]   = data1;
        data_int[2]   = data2;
        data_int[3]   = data3;
    //}

    // file dumping
    
    signatureFile.open(signatureFileName, std::ios::out | std::ios::app);
    if ( xcpt_cause != CAUSE_INSTR_PAGE_FAULT || !xcpt){  // Neiel-leyva
        signatureFile << "core   0: " << HEX_PC(PC) << " (" << HEX_INST(inst) << ") " << "DASM(" << HEX_INST(inst) << ")" << "\n";
    }

    //exceptions
    if (xcpt) {
        signatureFile.close();
        if (inst == 0x9f019073) dump_xcpt(xcpt_cause, PC, 0); //Write tohost, 0 in tval
        else dump_xcpt(xcpt_cause, PC, csr_tval);
        signatureFile.open(signatureFileName, std::ios::out | std::ios::app);
    }
    else {
        int opcode = inst & 0x7f;
        int func3 = (inst >> 12) & 0x7;
        int func6 = (inst >> 26) & 0x3f;
        int is_vext = 0;
        int is_vse = 0;
        if (opcode == 0x57 && func3 == 0x2 && func6 == 0x0c) is_vext = 1;
        if (opcode == 0x27 && func3 == 0x7) is_vse = 1;

        signatureFile << DEC_PRIV(csr_priv_lvl) << " " << HEX_PC(PC) << " (" << HEX_INST(inst) << ")";
        if (reg_wr_valid) {
            signatureFile << " " << DEC_DST(dst) << " " << HEX_DATA(signature[dst]);
        }
        if (freg_wr_valid) {
            signatureFile << " " << DEC_FDST(dst) << " " << HEX_DATA(signature[dst]);
        }
        if (vreg_wr_valid || is_vext || is_vse) {
            switch (sew) {
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
            if (vreg_wr_valid) {
                signatureFile << " " << DEC_VDST(vdst) << " 0x";
                for (int i = (VVLEN/32)-1; i >= 0; --i) {
                    signatureFile << HEX_VDATA(data_int[i]);
                }
            }
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
    signatureFile << "spike: " << HEX_PC(PC) << " (" << HEX_INST(inst) << ") " << "DASM(" << HEX_INST(inst) << ")" << "\n";
    signatureFile << " " << DEC_DST(dst) << " " << HEX_DATA(dst_value) << "\n";
    signatureFile.close();
}
    
