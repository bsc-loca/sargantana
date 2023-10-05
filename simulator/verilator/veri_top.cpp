// See LICENSE for license details.

#include <verilated.h>
#include <verilated_fst_c.h>
#include "Vveri_top.h"
#include <string>
#include <sstream>
#include <vector>
#include <iostream>
#include <cstdlib>
#include <memory>
#include <csignal>

#include <chrono>
#include <thread>

//#include "dpi_rename_checking.h" TODO: Ask Max about this

using std::string;
using std::vector;

void print_help(){

    std::cout << "Sargantana Verilator simulation flags: "<< std::endl << std::endl;

    std::cout << "+bootrom=<bootrom_path>"<< std::endl;
    std::cout << "\tSets the bootloader.hex file specified with the path to the bootrom."<< std::endl << std::endl;

    std::cout << "+konata_dump"<< std::endl;
    std::cout << "\tEnables the Konata dump of the simulation. The default output file is konata.txt"<< std::endl << std::endl;

    std::cout << "+konata_dump=<konata_output_path>"<< std::endl;
    std::cout << "\tSets the output file of Konata"<< std::endl << std::endl;

    std::cout << "+load="<< std::endl;
    std::cout << "\tSpecifies the elf program that the core will execute (the entry point must be 0x80000000)"<< std::endl << std::endl;
    
    std::cout << "+max-cycles="<< std::endl;
    std::cout << "\tSets the maximum cycles of the simulation."<< std::endl << std::endl;

    std::cout << "+commit_log"<< std::endl;
    std::cout << "\tEnables the signature dump of the commited instructions with the spike format. The default output file is signature.txt"<< std::endl << std::endl;

    std::cout << "+commit_log="<< std::endl;
    std::cout << "\tSets the output file of signature dump of the commited instructions"<< std::endl << std::endl;

    std::cout << "+vcd"<< std::endl;
    std::cout << "\tEnables the vcd trace on the simulation. The default output file is verilated.vcd"<< std::endl << std::endl;
}

bool stop_requested = false;

void signalHandler( int signum ) {
    std::cout << "Interrupt signal (" << signum << ") received." << std::endl;
    std::cout << "Stop requested." << std::endl;
    stop_requested = true;
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;

    // *** Argument Parsing ***

    vector<string> args(argv + 1, argv + argc);

    bool vcd_enable = false;

    for(vector<string>::iterator it = args.begin(); it != args.end(); ++it) {
        if(*it == "+help") {
            print_help();
            exit(0);
        } else if(it->find("+vcd", 0) == 0) { // Also handled by veri_top.sv
            vcd_enable = true;
        }
        // The rest of arguments are handled by the verilog DPIs
    }

    // *** Initialize Verilator Context ***

    ctx->debug(0);                  // Disable debugging, faster simulation speeds
    ctx->traceEverOn(vcd_enable);   // Enable vcd dump if requested
    ctx->assertOn(false);           // Disable asserts before reset is applied
    ctx->commandArgs(argc, argv);   // Pass arguments to verilog
    ctx->fatalOnError(false);       // Do not abort on errors, exit with an error code

    signal(SIGINT, signalHandler);  // Attach signal handler to catch interrupts and stop the simulation

    // *** Instantiate top level module ***
  
    Vveri_top *top = new Vveri_top(ctx, "TOP");
    top->rstn_i = 1;
    top->clk_i  = 0;

    top->eval();

    // *** Main Loop ***
    uint64_t main_time = 0;

    while(!ctx->gotFinish() && !stop_requested) {

        ctx->timeInc(1);

        if(main_time > 0) {
          top->rstn_i = 0;
        }

        if(main_time > 3) {
          top->rstn_i = 1;
          ctx->assertOn(true); // Enable asserts now that reset has been done
        }

        top->clk_i = ~top->clk_i;

        top->eval();

        main_time++;    
    }

    top->final();

    delete top;
    delete ctx;

    return ctx->gotError() ? -1 : 0;
}
