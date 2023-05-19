// See LICENSE for license details.

#include <verilated.h>
#include <verilated_fst_c.h>
#include "Vveri_top.h"
#include "globals.h"
#include "dpi_perfect_memory.h"
#include "dpi_host_behav.h"
#include <string>
#include <sstream>
#include <vector>
#include <iostream>
#include <cstdlib>
#include <memory>
#include <csignal>

#include <chrono>
#include <thread>

#include "dpi_torture.h"
#include "dpi_konata.h"
#include "dpi_rename_checking.h"

using std::string;
using std::vector;

Vveri_top *top;
uint64_t max_time = 0;
uint64_t start_vcd_time = 0;

double sc_time_stamp() { return main_time; }

std::string shell_exec(const std::string &cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) {
        std::cerr << "Unable to execute " << cmd << std::endl;
        exit(1);
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
}

void print_help(){

    std::cout << "Lagarto Lowrisc Verilator simulation flags: "<< std::endl << std::endl;

    std::cout << "+bootrom=<bootrom_path>"<< std::endl;
    std::cout << "\tSets the bootloader.hex file specified with the path to the bootrom."<< std::endl << std::endl;

    std::cout << "+checkpoint_cycles=<num_million_cycles>"<< std::endl;
    std::cout << "\tCreates a checkpoint every (num x million cycles)."<< std::endl << std::endl;
    
    std::cout << "+checkpoint_name=<path>"<< std::endl;
    std::cout << "\tName of the checkpoints."<< std::endl << std::endl;

    std::cout << "+checkpoint_restore_ON"<< std::endl;
    std::cout << "\tRestore a checkpoint state of the SoC of an other simulation."<< std::endl << std::endl;

    std::cout << "+checkpoint_restore_name=<path>"<< std::endl;
    std::cout << "\tName of the checkpoint to restore."<< std::endl << std::endl;

    std::cout << "+debug_addr=<addr in hex>" << std::endl;
    std::cout << "\tPrints the cycle every time when the core executes the instruction on PC=addr."<< std::endl << std::endl;

    std::cout << "+enableDebugPrintRead"<< std::endl;
    std::cout << "\tEnables the debug messages on the memory read accesses"<< std::endl << std::endl;

    std::cout << "+enableDebugPrintWrite"<< std::endl;
    std::cout << "\tEnables the debug messages on the memory write accesses"<< std::endl << std::endl;

    std::cout << "+konata_dump_ON"<< std::endl;
    std::cout << "\tEnables the Konata dump of the simulation. The default output file is konata.txt"<< std::endl << std::endl;

    std::cout << "+konata_dump=<konata_output_path>"<< std::endl;
    std::cout << "\tSets the output file of Konata"<< std::endl << std::endl;

    std::cout << "+load="<< std::endl;
    std::cout << "\tSpecifies the elf program that the core will execute (the entry point must be 0x80000000)"<< std::endl << std::endl;
    
    std::cout << "+max-cycles="<< std::endl;
    std::cout << "\tSets the maximum cycles of the simulation."<< std::endl << std::endl;

    std::cout << "+max_miss="<< std::endl;
    std::cout << "\tSets the maximum missmatches of the cosimulation before finishing."<< std::endl << std::endl;

    std::cout << "+signature="<< std::endl;
    std::cout << "\tSets the output file of the memory transactions signature"<< std::endl << std::endl;
    
    std::cout << "+start_vcd_time="<< std::endl;
    std::cout << "\tSets the starting cycle of the vcd trace."<< std::endl << std::endl;
    
    std::cout << "+tcp="<< std::endl;
    std::cout << "\t---"<< std::endl << std::endl;

    std::cout << "+terminal="<< std::endl;
    std::cout << "\t---"<< std::endl << std::endl;

    std::cout << "+torture_dump_ON"<< std::endl;
    std::cout << "\tEnables the signature dump of the commited instructions with the spike format. The default output file is signature.txt"<< std::endl << std::endl;

    std::cout << "+torture_dump="<< std::endl;
    std::cout << "\tSets the output file of signature dump of the commited instructions"<< std::endl << std::endl;

    std::cout << "+vcd"<< std::endl;
    std::cout << "\tEnables the vcd trace on the simulation. The default output file is verilated.vcd"<< std::endl << std::endl;
    
    std::cout << "+vcd_name="<< std::endl;
    std::cout << "\tSets the output file of the vcd trace"<< std::endl << std::endl;
}

void save_model(const char* filename) {
    VerilatedSave os;
    os.open(filename);
    os << main_time;  // user code must save the timestamp, etc
    //os << *memory_controller;
    os << *top;
}

void restore_model(const char* filename) {
    VerilatedRestore os;
    os.open(filename);
    os >> main_time;
    //os >> *memory_controller;
    os >> *top;
}

VerilatedFstC* fst;
bool vcd_enable = false;

void signalHandler( int signum ) {
   std::cout << "Interrupt signal (" << signum << ") received." << std::endl;

   if (vcd_enable) {
        std::cout << "Saving waveform..." << std::endl;
        fst->close();
   } 

   exit(signum);
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  // initialize memory model
  //memory_model_init();
  //axi_mem_reader->setDebugPrint(false);

    // Initialize step by step torture stats
    //torture_signature_init();
    konata_signature_init();
    rename_checking_init();

  // handle arguements
  string vcd_name = "verilated.vcd";

    //  handle arguments
    bool tcp_debug = false;
    string tortureSignatureFileName = "signature.txt";
    bool torture_dump_valid = false;
    string konataSignatureFileName = "konata.txt";
    string debug_addr = "0000000000000000";
    bool konata_dump_valid = false;
    string max_miss = "0000000000001000";
    uint64_t checkpoint_cycles = 0;
    string checkpointSaveFileName = "verilator_model";
    bool checkpointFile1 = true;
    bool checkpoint_restore = false;
    string checkpointRestoreFileName = "verilator_model_1.bin";
    bool checkpoint_error = true;
    bool rename_check_valid = false;

  // handle arguments for the terminal like interface from the host
  bool host_interface_enable = false;

  string sig_file;
  uint32_t sig_begin = 0, sig_end = 0;

  vector<string> args(argv + 1, argv + argc);
  vector<string>::iterator tail_args = args.end();

  // By default we use the enable in the same directory
  string bootrom = "./bootrom.hex";
  string filename;

  for(vector<string>::iterator it = args.begin(); it != args.end(); ++it) {
    if(*it == "--help") {
        print_help();
        exit(0);
    }
    else if(*it == "+vcd") {
        vcd_enable = true;
    }
    else if(it->find("+bootrom=") == 0) {
        bootrom = it->substr(strlen("+bootrom="));
    }
    else if(it->find("+load=") == 0) {
        filename = it->substr(strlen("+load="));
    }
    else if(it->find("+max-cycles=") == 0) {
         max_time = 10 * strtoul(it->substr(strlen("+max-cycles=")).c_str(), NULL, 10);
    }
    else if(it->find("+start_vcd_time=") == 0) {
        start_vcd_time = 10 * strtoul(it->substr(strlen("+start_vcd_time=")).c_str(), NULL, 10);
    }
    else if(it->find("+vcd_name=") == 0) {
        vcd_name = it->substr(strlen("+vcd_name="));
    }
    else if (it->find("+signature=") == 0) {
        sig_file = it->substr(strlen("+signature="));
    }
    else if(it->find("+tcp") == 0) {
        tcp_debug = true;
    }
    else if(it->find("+torture_dump_ON") == 0) {
        torture_dump_valid = true;
    }
    else if(it->find("+torture_dump=") == 0) {
        tortureSignatureFileName = it->substr(strlen("+torture_dump="));
    }
    else if(it->find("+konata_dump_ON") == 0) {
        konata_dump_valid = true;
    }
    else if(it->find("+konata_dump=") == 0) {
        konataSignatureFileName = it->substr(strlen("+konata_dump="));
    }
    else if(it->find("+rename_check") == 0) {
        rename_check_valid = true;
    }
    else if (it->find("+terminal") == 0) {
        host_interface_enable = true;
    }
    else if (it->find("+debug_addr=") == 0) {
        debug_addr = it->substr(strlen("+debug_addr="));
    }
    else if (it->find("+max_miss=") == 0) {
        max_miss = it->substr(strlen("+max_miss="));
    }
    else if (it->find("+checkpoint_cycles=") == 0) {
        checkpoint_cycles = 10 * 1000000 * strtoul(it->substr(strlen("+checkpoint_cycles=")).c_str(), NULL, 10);
    }
    else if (it->find("+checkpoint_name=") == 0) {
        checkpointSaveFileName = it->substr(strlen("+checkpoint_name="));
    }
    else if (it->find("+checkpoint_restore_ON") == 0) {
        checkpoint_restore = true;
    }
    else if (it->find("+checkpoint_restore_name=") == 0) {
        checkpointRestoreFileName = it->substr(strlen("+checkpoint_restore_name="));
    }
    else if (it->find("+enableDebugPrintRead") == 0) {
        memory_enable_read_debug();
    }
    else if (it->find("+enableDebugPrintWrite") == 0) {
        //axi_mem_writer->setDebugPrint(true);
    }
    else if (it->find("+verilator") == 0) {
    }
    else {
        if (it->find("+") == 0) {
            std::cerr << "Error: Unrecognized argument '" << *it << "'." << std::endl;
            print_help();
            exit(1);
        } else {
            tail_args = it;
        }
    }
  }

  if (filename.empty()) {
    std::cerr << "Error: Must supply a filename via +load=<path>" << std::endl;
    exit(1);
  }
  
  torture_signature_init(&filename[0]);
  
  if (checkpoint_restore) {
      top = new Vveri_top;
      restore_model(checkpointRestoreFileName.c_str());
  }
  else {
      memory_init(filename);
  }
  // Handle binary argument
  if (tail_args != args.end()) {
    string bin_file = *tail_args;
    string hex_file = bin_file + ".hex";

    std::stringstream cmd;
    cmd << "(elf2hex 16 8192 " << bin_file << " || elf2hex 16 16384 " << bin_file << ") > " << hex_file;
    shell_exec(cmd.str());
    /*if(!memory_controller->load_mem(hex_file, "./ERRORbootrom.hex")) {
      std::cout << "fail to load memory file lel " << hex_file << std::endl;
      return 0;
    }*/

    cmd.str("");
    cmd << "nm " << bin_file << " | awk '/begin_signature/{print $1}'";
    sig_begin = std::stoi(shell_exec(cmd.str()), nullptr, 16);
    cmd.str("");
    cmd << "nm " << bin_file << " | awk '/end_signature/{print $1}'";
    sig_end = std::stoi(shell_exec(cmd.str()), nullptr, 16);
  }

  top = new Vveri_top;
  top->rst_top = 0;
  top->i_dr_dis = 1;
  top->eval();

  // VCD dump
  if(vcd_enable) {
    fst = new VerilatedFstC;
    Verilated::traceEverOn(true);
    top->trace(fst, 99);
    fst->open(vcd_name.c_str());
  }

  signal(SIGINT, signalHandler); 

    // torture signature print options
    torture_signature->set_dump_file_name(tortureSignatureFileName);
    torture_signature->set_debug_addr(debug_addr);
    torture_signature->set_max_miss(max_miss);
    if(torture_dump_valid == false)
        torture_signature->disable();
    else
        torture_signature->clear_output(); // reset the output file


    if(host_interface_enable == true)
        host_init_interface();
    
    konata_signature->set_dump_file_name(konataSignatureFileName);
    if (konata_dump_valid == false)
        konata_signature->disable();
    else
        konata_signature->clear_output(); // reset the output file
    
    if (rename_check_valid == false)
        rename_checking_int->disable();
        

    //#####################################################################
    //########################## MAIN LOOP ################################
    //#####################################################################
    while(!Verilated::gotFinish() && (!exit_code || exit_delay > 1) &&
           (max_time == 0 || main_time < max_time) && finish_due_renaming_error == 0 &&
	   (exit_delay != 1) && (!torture_dump_valid || torture_signature->dump_check()) 
	   ) {

        if (checkpoint_cycles != 0 && (main_time % checkpoint_cycles) == 0 && main_time != 0) {
            if (checkpointFile1) {
                save_model((checkpointSaveFileName + "_1.bin").c_str());
                checkpointFile1 = false;
            }
            else {
                save_model((checkpointSaveFileName + "_2.bin").c_str());
                checkpointFile1 = true;
            }
        }
        
        if (torture_signature->get_first_missmatch() && checkpoint_error) {
            save_model((checkpointSaveFileName + "_error.bin").c_str());
            checkpoint_error = false;
        }

        if(main_time > 32) {
          top->rst_top = 1;
        }

        if(main_time > 147) {
          top->rst_top = 0;
        }
        if((main_time % 10) == 0) { // 10ns clk
          top->clk_p = 1;
          top->clk_n = 0;
        }
        if((main_time % 10) == 5) {
          top->clk_p = 0;
          top->clk_n = 1;
        }

        top->eval();

        //if((main_time % 10) == 0) memory_controller->step();

        if (vcd_enable && main_time > start_vcd_time) fst->dump(main_time);

        if(main_time < 140)
        main_time++;
        else
        main_time += 5;

        if((main_time % 10) == 0 && exit_delay > 1)
        exit_delay--;             // postponed delay to allow VCD recording
    
    }

    if (!sig_file.empty()) {
        if (sig_begin == 0 || sig_end == 0) {
        std::cerr << "No address for signature symbols" << std::endl;
        exit(1);
        }
        //memory_controller->save_mem(sig_file, sig_begin, sig_end);
    }

    top->final();
    if(vcd_enable) fst->close();

    #if VM_COVERAGE
        VerilatedCov::write("logs/coverage.dat");
    #endif

    delete top;
    //memory_model_close();

    if (max_time != 0 && main_time >= max_time) {
        exit_code = -1;
        std::cerr << " ERROR: Time out at " << max_time << " cicles" << std::endl;
    }

    return exit_code;
}
