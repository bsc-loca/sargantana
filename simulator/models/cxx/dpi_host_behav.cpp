// See LICENSE for license details.

#ifdef VERILATOR_GCC
#include <verilated.h>
#endif

#include "globals.h"
#include "dpi_host_behav.h"
#include <cstdlib>
#include <iostream>

#include <stdlib.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <iostream>
#include <sstream>
#include <fstream>

// Commands definition
#define SYS_write 64

void host_req (unsigned int id, unsigned long long data) {
  if(data & 1) {
    // test pass/fail
    if(host_extract_payload(data) != 1) {
      std::cout << "Core " << id << " exit with error code " << (host_extract_payload(data) >> 1) << std::endl;
    #ifdef INCISIVE_SIMULATION
      // Flag used so error/success message is printed only once
      if(!output_message_flag) {
        output_message_flag++;
        std::ofstream results;
        results.open("results.txt", std::ios::out | std::ios::app);
        results << "Core " << id << " exit with error code " << (host_extract_payload(data) >> 1) << std::endl;
        results.close();
      }
    #endif
      exit_code = host_extract_payload(data) >> 1;
      exit_delay = 1;
    }
    #ifdef INCISIVE_SIMULATION
    else {
      std::cout << "Success" << std::endl;
      // Flag used so error/success message is printed only once
      if(!output_message_flag) {
        output_message_flag++;
        std::ofstream results;
        results.open("results.txt", std::ios::out | std::ios::app);
        results << "Success" << std::endl;
        results.close();
      }      
      exit_code = 0;
      exit_delay = 1;
    }
    output_message_flag++;
    #else
    else {
      std::cout << "Run finished correctly" << std::endl;
      exit_code = 0;
      exit_delay = 1;
    }
    #endif
    std::cout << "Run time is : " << main_time << std::endl;
  } else {
    if (host_extract_cmd_(data) == SYS_write) {
      // Printing the value
      //std::cout << "CHAR : " << host_extract_char(data) << std::endl;
      std::cerr << host_extract_char(data);
    } else {
      //std::cerr << "Core " << id << " get unsolved tohost code " << std::hex << data << std::endl;
      std::cout << "Core " << id << " get unsolved tohost code " << std::hex << data << std::endl;

      //exit_code = 1;
      //exit_delay = 1;
    }
  }
}

// Function to init a terminal like interface to output all the printf functions
void host_init_interface(){

  int pt = posix_openpt(O_RDWR);
  if (pt == -1)
  {
    std::cerr << "Could not open pseudo terminal.\n";
//    return EXIT_FAILURE;
  }
  char* ptname = ptsname(pt);
  if (!ptname)
  {
    std::cerr << "Could not get pseudo terminal device name.\n";
    close(pt);
//    return EXIT_FAILURE;
  }

  if (unlockpt(pt) == -1)
  {
    std::cerr << "Could not get pseudo terminal device name.\n";
    close(pt);
//    return EXIT_FAILURE;
  }

  std::ostringstream oss;
  oss << "xterm -fa 'Monospace' -fs 14 -S" << (strrchr(ptname, '/')+1) << "/" << pt << " &";
  system(oss.str().c_str());

  int xterm_fd = open(ptname,O_RDWR);
  char c;
  do read(xterm_fd, &c, 1); while (c!='\n');

/*  if (dup2(pt, 1) <0)
  {
    std::cerr << "Could not redirect standard output.\n";
    close(pt);
//    return EXIT_FAILURE;
  }*/
  if (dup2(pt, 2) <0)
  {
    std::cerr << "Could not redirect standard error output.\n";
    close(pt);
//    return EXIT_FAILURE;
  }

//  std::cout << "This should appear on the xterm." << std::endl;
  std::cerr << "LAGARTO TERMINAL INTERFACE:\n";
//  std::cin.ignore(1);

//  close(pt);
//  return EXIT_SUCCESS
}
