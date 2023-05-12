// See LICENSE for license details.

#ifndef GLOBALS_H
#define GLOBALS_H

#include <cstdint>

extern uint64_t main_time;
extern unsigned int exit_delay;
extern unsigned int exit_code;
extern int finish_due_renaming_error;

#ifdef INCISIVE_SIMULATION
extern unsigned int output_message_flag;
#endif
#endif
