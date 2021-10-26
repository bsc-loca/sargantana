// *******************************************************************************************************
// **                                                                                                   **
// **   25CSM04.v - Microchip 25CSM04 4M-BIT SPI SERIAL EEPROM (VCC = +2.5V TO +5.5V)                   **
// **                                                                                                   **
// *******************************************************************************************************
// **                                                                                                   **
// **                   This information is distributed under license from Young Engineering.           **
// **                              COPYRIGHT (c) 2021 YOUNG ENGINEERING                                 **
// **                                      ALL RIGHTS RESERVED                                          **
// **                                                                                                   **
// **                                                                                                   **
// **   Young Engineering provides design expertise for the digital world                               **
// **   Started in 1990, Young Engineering offers products and services for your electronic design      **
// **   project.  We have the expertise in PCB, FPGA, ASIC, firmware, and software design.              **
// **   From concept to prototype to production, we can help you.                                       **
// **                                                                                                   **
// **   http://www.young-engineering.com/                                                               **
// **                                                                                                   **
// *******************************************************************************************************
// **   This information is provided to you for your convenience and use with Microchip products only.  **
// **   Microchip disclaims all liability arising from this information and its use.                    **
// **                                                                                                   **
// **   THIS INFORMATION IS PROVIDED "AS IS." MICROCHIP MAKES NO REPRESENTATION OR WARRANTIES OF        **
// **   ANY KIND WHETHER EXPRESS OR IMPLIED, WRITTEN OR ORAL, STATUTORY OR OTHERWISE, RELATED TO        **
// **   THE INFORMATION PROVIDED TO YOU, INCLUDING BUT NOT LIMITED TO ITS CONDITION, QUALITY,           **
// **   PERFORMANCE, MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR PURPOSE.                         **
// **   MICROCHIP IS NOT LIABLE, UNDER ANY CIRCUMSTANCES, FOR SPECIAL, INCIDENTAL OR CONSEQUENTIAL      **
// **   DAMAGES, FOR ANY REASON WHATSOEVER.                                                             **
// **                                                                                                   **
// **   It is your responsibility to ensure that your application meets with your specifications.       **
// **                                                                                                   **
// *******************************************************************************************************
// **   Revision       : 1.0                                                                            **
// **   Modified Date  : 2/22/2021                                                                      **
// **   Revision History:                                                                               **
// **                                                                                                   **
// **   2/22/2021:  Initial design                                                                      **
// **                                                                                                   **
// *******************************************************************************************************
// **                                       TABLE OF CONTENTS                                           **
// *******************************************************************************************************
// **---------------------------------------------------------------------------------------------------**
// **   DECLARATIONS                                                                                    **
// **---------------------------------------------------------------------------------------------------**
// **---------------------------------------------------------------------------------------------------**
// **   INITIALIZATION                                                                                  **
// **---------------------------------------------------------------------------------------------------**
// **---------------------------------------------------------------------------------------------------**
// **   CORE LOGIC                                                                                      **
// **---------------------------------------------------------------------------------------------------**
// **   1.01:  Internal Reset Logic                                                                     **
// **   1.02:  Input Data Shifter                                                                       **
// **   1.03:  Bit Clock Counter                                                                        **
// **   1.04:  Instruction Register                                                                     **
// **   1.05:  Address Register                                                                         **
// **   1.06:  Write Data Buffer                                                                        **
// **   1.07:  Write Enable/Disable and Software Reset Instructions                                     **
// **   1.08:  EEPROM Write Protection Logic                                                            **
// **   1.09:  EEPROM Write Operation Logic                                                             **
// **   1.10:  Status Reg Write Operation Logic                                                         **
// **   1.11:  Security Reg Write Protection Logic                                                      **
// **   1.12:  Security Reg Write Operation Logic                                                       **
// **   1.13:  Security Reg Lock Operation Logic                                                        **
// **   1.14:  Memory Partition Reg Write Protection Logic                                              **
// **   1.15:  Memory Partition Reg Write Operation Logic                                               **
// **   1.16:  Protect Partition Address Boundaries Operation Logic                                     **
// **   1.17:  Freeze Memory Protection Configuration Operation Logic                                   **
// **   1.18:  Output Data Shifter                                                                      **
// **   1.19:  Output Data Buffer                                                                       **
// **                                                                                                   **
// **---------------------------------------------------------------------------------------------------**
// **   LOGIC FUNCTIONS                                                                                 **
// **---------------------------------------------------------------------------------------------------**
// **   2.01:  FindMPR - Find applicable MPR for a given address                                        **
// **                                                                                                   **
// **---------------------------------------------------------------------------------------------------**
// **   DEBUG LOGIC                                                                                     **
// **---------------------------------------------------------------------------------------------------**
// **   3.01:  Memory Data Bytes                                                                        **
// **   3.02:  Page Buffer Bytes                                                                        **
// **   3.03:  Security Register Bytes                                                                  **
// **   3.04:  Memory Partition Register Bytes                                                          **
// **                                                                                                   **
// **---------------------------------------------------------------------------------------------------**
// **   TIMING CHECKS                                                                                   **
// **---------------------------------------------------------------------------------------------------**
// **                                                                                                   **
// *******************************************************************************************************

`timescale 1ns/1ps

module M25CSM04 (CS_N, SO, WP_N, SI, SCK, HOLD_N, RESET);

   input                SI;                             // serial data input
   input                SCK;                            // serial data clock
   input                CS_N;                           // chip select - active low
   input                WP_N;                           // write protect pin - active low
   input                HOLD_N;                         // interface suspend - active low
   input                RESET;                          // model reset/power-on reset
   output               SO;                             // serial data output


// *******************************************************************************************************
// **   DECLARATIONS                                                                                    **
// *******************************************************************************************************

   parameter            SERIAL_NUM_0 = 8'hFF;           // default value
   parameter            SERIAL_NUM_1 = 8'hFF;           // default value
   parameter            SERIAL_NUM_2 = 8'hFF;           // default value
   parameter            SERIAL_NUM_3 = 8'hFF;           // default value
   parameter            SERIAL_NUM_4 = 8'hFF;           // default value
   parameter            SERIAL_NUM_5 = 8'hFF;           // default value
   parameter            SERIAL_NUM_6 = 8'hFF;           // default value
   parameter            SERIAL_NUM_7 = 8'hFF;           // default value
   parameter            SERIAL_NUM_8 = 8'hFF;           // default value
   parameter            SERIAL_NUM_9 = 8'hFF;           // default value
   parameter            SERIAL_NUM_A = 8'hFF;           // default value
   parameter            SERIAL_NUM_B = 8'hFF;           // default value
   parameter            SERIAL_NUM_C = 8'hFF;           // default value
   parameter            SERIAL_NUM_D = 8'hFF;           // default value
   parameter            SERIAL_NUM_E = 8'hFF;           // default value
   parameter            SERIAL_NUM_F = 8'hFF;           // default value

   parameter            STATUS_REG_DEFAULTS = 16'h0000; // default value
   
   parameter            MPR_0 = 8'h00;                  // default value
   parameter            MPR_1 = 8'h00;                  // default value
   parameter            MPR_2 = 8'h00;                  // default value
   parameter            MPR_3 = 8'h00;                  // default value
   parameter            MPR_4 = 8'h00;                  // default value
   parameter            MPR_5 = 8'h00;                  // default value
   parameter            MPR_6 = 8'h00;                  // default value
   parameter            MPR_7 = 8'h00;                  // default value

   parameter            MAN_ID = 40'h29_CC_00_01_00;    // manufacturer ID value

   reg  [23:00]         DataShifterI;                   // serial input data shifter
   reg  [07:00]         DataShifterO;                   // serial output data shifter
   reg  [31:00]         BitCounter;                     // serial input bit counter
   reg  [07:00]         InstRegister;                   // instruction register
   reg  [23:00]         AddrRegister;                   // address register

   // Decoded STATUS Register Instructions
   wire InstructionRDSR;
   wire InstructionWRBP;
   wire InstructionWREN;
   wire InstructionWRDI;
   wire InstructionWRSR;
   // Decoded EEPROM and Security Register Instructions
   wire InstructionREAD;
   wire InstructionWRITE;
   wire InstructionRDEX;
   wire InstructionWREX;
   wire InstructionLOCK;
   wire InstructionCHLK;
   // Decoded Memory Partition Register Instructions
   wire InstructionRMPR;
   wire InstructionPRWE;
   wire InstructionPRWD;
   wire InstructionWMPR;
   wire InstructionPPAB;
   wire InstructionFRZR;
   // Decoded Identification Register Instructions
   wire InstructionSPID;
   // Decoded Device Reset Instruction
   wire InstructionSRST;

   reg  [07:00]         PageBuffer [0:255];             // memory write data buffer
   reg                  BufferWrFlags [0:255];          // memory buffer write flags
   
   reg                  SecRegLock;                     // Security register lock bit

   reg                  WriteActive;                    // write operation in progress
   
   event                EEPROM_WrEvent;                 // EEPROM write event
   event                STATUS_WrEvent;                 // Status register write event
   event                MPR_WrEvent;                    // Memory partition register write event
   event                SECREG_WrEvent;                 // Security register write event
   event                SECREG_LockEvent;               // Security register lock event
   event                PPAB_SetEvent;                  // Protect Partition Address Boundary set event
   event                PPAB_ClearEvent;                // Protect Partition Address Boundary clear event
   event                FRZR_Event;                     // Freeze Memory Protection Configuration event

   reg                  STATUS_WPEN;                    // write protect enable bit
   reg [01:00]          STATUS_BP;                      // block protection bits
   reg                  STATUS_WEL;                     // write enable latch bit
   reg                  STATUS_WPM;                     // write protection mode bit
   wire                 STATUS_ECS;                     // error correction status bit, read-only
   reg                  STATUS_FMPC;                    // freeze memory protection configuration bit
   reg                  STATUS_PREL;                    // partition register write enable latch bit
   reg                  STATUS_PABP;                    // partition address boundary protection bit

   wire                 HardwareWriteProtected;         // hardware write protected
   
   reg                  EEPROMWriteProtected;           // EEPROM write protected
   reg                  SecRegWriteProtected;           // Security reg write protected
   reg                  MPRWriteProtected;              // Memory partition reg write protected
   
   reg  [15:00]         StatusRegBuffer;                // status reg buffer
   reg  [07:00]         MPRBuffer;                      // memory partition reg buffer

   reg  [07:00]         MemoryBlock [0:524287];         // EEPROM data memory array (524288x8)
   reg  [07:00]         SecurityReg [0:511];            // Security reg memory array (512x8)
   
   reg  [07:00]         MPR [07:00];                    // memory partition registers
   
   reg  [07:00]         EffectiveMPR;                   // applicable MPR for current address
    
   reg                  SO_DO;                          // serial output data - data
   wire                 SO_OE;                          // serial output data - output enable

   reg                  SO_Enable;                      // serial data output enable

   wire                 OutputEnable1;                  // timing accurate output enable
   wire                 OutputEnable2;                  // timing accurate output enable
   wire                 OutputEnable3;                  // timing accurate output enable

   integer              LoopIndex;                      // iterative loop index

   integer              tWC;                            // timing parameter
   integer              tV;                             // timing parameter
   integer              tHZ;                            // timing parameter
   integer              tHV;                            // timing parameter
   integer              tDIS;                           // timing parameter

`define RDSR            8'b0000_0101                    // Read Status Register instruction
`define WRBP            8'b0000_1000                    // Write Ready/Busy Poll instruction
`define WREN            8'b0000_0110                    // Set Write Enable Latch instruction
`define WRDI            8'b0000_0100                    // Reset Write Enable Latch instruction
`define WRSR            8'b0000_0001                    // Write Status Register instruction
`define READ            8'b0000_0011                    // Read EEPROM Array instruction
`define WRITE           8'b0000_0010                    // Write EEPROM Array instruction
`define RDEX            8'b1000_0011                    // Read Security Register instruction
`define WREX            8'b1000_0010                    // Write Security Register instruction
`define LOCK            8'b1000_0010                    // Lock Security Register instruction
`define CHLK            8'b1000_0011                    // Check Security Register Lock Status instruction
`define RMPR            8'b0011_0001                    // Read Memory Partition Registers instruction
`define PRWE            8'b0000_0111                    // Set MPR Write Enable Latch instruction
`define PRWD            8'b0000_1010                    // Reset MPR Write Enable Latch instruction
`define WMPR            8'b0011_0010                    // Write Memory Partition Registers instruction
`define PPAB            8'b0011_0100                    // Protect Partition Address Boundaries instruction
`define FRZR            8'b0011_0111                    // Freeze Memory Protection Configuration instruction
`define SPID            8'b1001_1111                    // Read Manufacturer ID instruction
`define SRST            8'b0111_1100                    // Software Device Reset instruction

// *******************************************************************************************************
// **   INITIALIZATION                                                                                  **
// *******************************************************************************************************
 
   initial begin
      `ifdef VCC_2_5V_TO_3_0V
         tV   = 80;                                     // output valid from SCK low
         tHZ  = 80;                                     // HOLD_N low to output high-Z
         tHV  = 80;                                     // HOLD_N high to output valid
         tDIS = 80;                                     // CS_N high to output disable
      `else
      `ifdef VCC_3_0V_TO_5_5V
         tV   = 40;                                     // output valid from SCK low
         tHZ  = 40;                                     // HOLD_N low to output high-Z
         tHV  = 40;                                     // HOLD_N high to output valid
         tDIS = 40;                                     // CS_N high to output disable
      `else
         tV   = 40;                                     // output valid from SCK low
         tHZ  = 40;                                     // HOLD_N low to output high-Z
         tHV  = 40;                                     // HOLD_N high to output valid
         tDIS = 40;                                     // CS_N high to output disable
      `endif
      `endif
      tWC  = 5000000;                                   // memory write cycle time
   end

   initial begin
      SecurityReg[0] <= SERIAL_NUM_0;
      SecurityReg[1] <= SERIAL_NUM_1;
      SecurityReg[2] <= SERIAL_NUM_2;
      SecurityReg[3] <= SERIAL_NUM_3;
      SecurityReg[4] <= SERIAL_NUM_4;
      SecurityReg[5] <= SERIAL_NUM_5;
      SecurityReg[6] <= SERIAL_NUM_6;
      SecurityReg[7] <= SERIAL_NUM_7;
      SecurityReg[8] <= SERIAL_NUM_8;
      SecurityReg[9] <= SERIAL_NUM_9;
      SecurityReg[10] <= SERIAL_NUM_A;
      SecurityReg[11] <= SERIAL_NUM_B;
      SecurityReg[12] <= SERIAL_NUM_C;
      SecurityReg[13] <= SERIAL_NUM_D;
      SecurityReg[14] <= SERIAL_NUM_E;
      SecurityReg[15] <= SERIAL_NUM_F;
      
      SecRegLock <= 0;

      WriteActive <= 0;

      STATUS_WPEN <= STATUS_REG_DEFAULTS[15];
      STATUS_BP <= STATUS_REG_DEFAULTS[11:10];
      STATUS_WPM <= STATUS_REG_DEFAULTS[7];
      STATUS_FMPC <= STATUS_REG_DEFAULTS[5];
      STATUS_PABP <= STATUS_REG_DEFAULTS[3];
      
      STATUS_WEL <= 0;
      STATUS_PREL <= 0;
   end

   initial begin
    $readmemh("bootrom_content.hex", MemoryBlock);
   end

   assign STATUS_ECS = 0;                               // ECC not modeled, ECS bit always remains 0

// *******************************************************************************************************
// **   CORE LOGIC                                                                                      **
// *******************************************************************************************************
// -------------------------------------------------------------------------------------------------------
//      1.01:  Internal Reset Logic
// -------------------------------------------------------------------------------------------------------

   always @(negedge CS_N) BitCounter   <= 0;
   always @(negedge CS_N) SO_Enable    <= 0;
   
   always @(negedge CS_N) begin
      if (!WriteActive) begin
         for (LoopIndex = 0; LoopIndex < 256; LoopIndex = LoopIndex + 1) begin
            BufferWrFlags[LoopIndex] <= 0;
         end
      end
   end
   
   always @(posedge CS_N) InstRegister <= #1 0;
   
// -------------------------------------------------------------------------------------------------------
//      1.02:  Input Data Shifter
// -------------------------------------------------------------------------------------------------------

   always @(posedge SCK) begin
      if (HOLD_N == 1) begin
         if (CS_N == 0)         DataShifterI <= {DataShifterI[22:00],SI};
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.03:  Bit Clock Counter
// -------------------------------------------------------------------------------------------------------

   always @(posedge SCK) begin
      if (HOLD_N == 1) begin
         if (CS_N == 0)         BitCounter <= BitCounter + 1;
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.04:  Instruction Register
// -------------------------------------------------------------------------------------------------------

   always @(posedge SCK) begin
      if (HOLD_N == 1) begin
         if (BitCounter == 7)   InstRegister <= {DataShifterI[06:00],SI};
      end
   end
   
    /*STATUS Register Instructions*/
    assign InstructionRDSR  = (InstRegister[7:0] == `RDSR);
    assign InstructionWRBP  = (InstRegister[7:0] == `WRBP);
    assign InstructionWREN  = (InstRegister[7:0] == `WREN);
    assign InstructionWRDI  = (InstRegister[7:0] == `WRDI); 
    assign InstructionWRSR  = (InstRegister[7:0] == `WRSR);
    /*EEPROM and Security Register Instructions*/   
    assign InstructionREAD  = (InstRegister[7:0] == `READ);
    assign InstructionWRITE = (InstRegister[7:0] == `WRITE);
    // RDEX/WREX share codes with CHLK/LOCK; they are differentiated by address bit A10
    assign InstructionRDEX = (InstRegister[7:0] == `RDEX & (AddrRegister[10] == 0));
    assign InstructionWREX = (InstRegister[7:0] == `WREX & (AddrRegister[10] == 0));
    assign InstructionLOCK = (InstRegister[7:0] == `LOCK & (AddrRegister[10] == 1));
    assign InstructionCHLK = (InstRegister[7:0] == `CHLK & (AddrRegister[10] == 1));
    /*Memory Partition Register Instructions*/
    assign InstructionRMPR = (InstRegister[7:0] == `RMPR);
    assign InstructionPRWE = (InstRegister[7:0] == `PRWE);
    assign InstructionPRWD = (InstRegister[7:0] == `PRWD);
    assign InstructionWMPR = (InstRegister[7:0] == `WMPR);
    assign InstructionPPAB = (InstRegister[7:0] == `PPAB);
    assign InstructionFRZR = (InstRegister[7:0] == `FRZR); 
    /*Identification Register Instructions*/
    assign InstructionSPID = (InstRegister[7:0] == `SPID);
    /*Device Reset Instruction*/
    assign InstructionSRST = (InstRegister[7:0] == `SRST);
    
// -------------------------------------------------------------------------------------------------------
//      1.05:  Address Register
// -------------------------------------------------------------------------------------------------------

   always @(posedge SCK) begin
      if (HOLD_N == 1) begin
         if ((BitCounter == 31) & !WriteActive) 
            AddrRegister <= {DataShifterI[22:00],SI};
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.06:  Write Data Buffer
// -------------------------------------------------------------------------------------------------------

   always @(posedge SCK) begin
      if (HOLD_N == 1) begin
         if ((BitCounter >= 39) & (BitCounter[2:0] == 7) & !WriteActive) begin
            if (InstructionWRITE | InstructionWREX) begin
               PageBuffer[AddrRegister[7:0]] <= {DataShifterI[06:00],SI};
               BufferWrFlags[AddrRegister[7:0]] <= 1;
               
               AddrRegister[07:00] <= AddrRegister[07:00] + 8'd1;
            end
         end
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.07:  Write Enable/Disable and Software Reset Instructions
// -------------------------------------------------------------------------------------------------------

   always @(posedge CS_N) begin
      if (HOLD_N == 1) begin
         if ((BitCounter >= 8) & !WriteActive) begin
            if (InstructionWREN) STATUS_WEL <= 1;
            else if (InstructionWRDI) STATUS_WEL <= 0;
            else if (InstructionPRWE & STATUS_WEL) STATUS_PREL <= 1;    // Can only set PREL after WEL is set
            else if (InstructionPRWD) STATUS_PREL <= 0;
            else if (InstructionSRST) begin
               STATUS_WEL <= 0;
               STATUS_PREL <= 0;
            end
         end
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.08:  EEPROM Write Protection Logic
// -------------------------------------------------------------------------------------------------------
   
   always @(AddrRegister or negedge SCK or WP_N) begin
      if (STATUS_WPM) begin
         // Enhanced write protection mode
         EffectiveMPR = FindMPR(AddrRegister);
         
         case (EffectiveMPR[7:6])
            2'b00: EEPROMWriteProtected <= 0;
            2'b01: EEPROMWriteProtected <= 1;
            2'b10: EEPROMWriteProtected <= !WP_N;   // Note, WP is not gated by WPEN in this case
            2'b11: EEPROMWriteProtected <= 1;
         endcase
      end
      else begin
         // Legacy write protection mode
         case (STATUS_BP)
            2'b00: EEPROMWriteProtected <= 0;
            2'b01: EEPROMWriteProtected <= (AddrRegister >= 19'h60000);
            2'b10: EEPROMWriteProtected <= (AddrRegister >= 19'h40000);
            2'b11: EEPROMWriteProtected <= 1;
         endcase
      end
   end
   
// -------------------------------------------------------------------------------------------------------
//      1.09:  EEPROM Write Operation Logic
// -------------------------------------------------------------------------------------------------------

   always @(posedge CS_N) begin
      if (HOLD_N == 1) begin
         if (InstructionWRITE & STATUS_WEL & !WriteActive & !EEPROMWriteProtected) begin
            if ((BitCounter >= 40) & (BitCounter[2:0] == 0)) begin
               ->EEPROM_WrEvent;
            end
         end
      end
   end
   
   always @(EEPROM_WrEvent) begin
      WriteActive = 1;
      #(tWC);
      WriteActive <= 0;
      STATUS_WEL <= 0;
      for (LoopIndex = 0; LoopIndex < 256; LoopIndex = LoopIndex + 1) begin
         if (BufferWrFlags[LoopIndex]) begin
            MemoryBlock[{AddrRegister[18:8],LoopIndex[7:0]}] = PageBuffer[LoopIndex];
         end
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.10:  Status Reg Write Operation Logic
// -------------------------------------------------------------------------------------------------------

   always @(posedge CS_N) begin
      if (HOLD_N == 1) begin
         if (InstructionWRSR & STATUS_WEL & !WriteActive & !HardwareWriteProtected) begin
            if (BitCounter == 16) begin
               StatusRegBuffer <= {DataShifterI[07:00],STATUS_WPM,7'h00};
               ->STATUS_WrEvent;
            end
            else if (BitCounter == 24) begin
               StatusRegBuffer <= DataShifterI[15:00];
               ->STATUS_WrEvent;
            end
         end
      end
   end
   
   always @(STATUS_WrEvent) begin
      WriteActive = 1;
      #(tWC);
      WriteActive <= 0;
      STATUS_WEL <= 0;
      STATUS_WPEN <= StatusRegBuffer[15];
      STATUS_BP <= StatusRegBuffer[11:10];
      if (!STATUS_FMPC) STATUS_WPM <= StatusRegBuffer[07];   // WPM can only be modified if FMPC is not set
   end

   assign HardwareWriteProtected = (STATUS_WPEN & !WP_N);   

// -------------------------------------------------------------------------------------------------------
//      1.11:  Security Reg Write Protection Logic
// -------------------------------------------------------------------------------------------------------
   
   always @(AddrRegister or negedge SCK) begin
      if (AddrRegister[8] == 1'b0 | SecRegLock) SecRegWriteProtected <= 1;
      else if (!STATUS_WPM & (STATUS_BP == 2'b11)) SecRegWriteProtected <= 1;
      else SecRegWriteProtected <= 0;
   end
   
// -------------------------------------------------------------------------------------------------------
//      1.12:  Security Reg Write Operation Logic
// -------------------------------------------------------------------------------------------------------

   always @(posedge CS_N) begin
      if (HOLD_N == 1) begin
         if (InstructionWREX & STATUS_WEL & !WriteActive & !SecRegWriteProtected) begin
            if ((BitCounter >= 40) & (BitCounter[2:0] == 0)) begin
               ->SECREG_WrEvent;
            end
         end
      end
   end
   
   always @(SECREG_WrEvent) begin
      WriteActive = 1;
      #(tWC);
      WriteActive <= 0;
      STATUS_WEL <= 0;
      for (LoopIndex = 0; LoopIndex < 256; LoopIndex = LoopIndex + 1) begin
         if (BufferWrFlags[LoopIndex]) begin
            SecurityReg[{1'b1,LoopIndex[7:0]}] = PageBuffer[LoopIndex];
         end
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.13:  Security Reg Lock Operation Logic
// -------------------------------------------------------------------------------------------------------

   always @(posedge CS_N) begin
      if (HOLD_N == 1) begin
         if (InstructionLOCK & STATUS_WEL & !WriteActive & !SecRegLock & !HardwareWriteProtected) begin
            if ((BitCounter == 40) & (DataShifterI[01] == 1'b1)) begin
               ->SECREG_LockEvent;
            end
         end
      end
   end
   
   always @(SECREG_LockEvent) begin
      WriteActive = 1;
      #(tWC);
      WriteActive <= 0;
      STATUS_WEL <= 0;
      SecRegLock <= 1;
   end

// -------------------------------------------------------------------------------------------------------
//      1.14:  Memory Partition Reg Write Protection Logic
// -------------------------------------------------------------------------------------------------------
   
   always @(AddrRegister or negedge SCK or HardwareWriteProtected) begin
      if (STATUS_FMPC | HardwareWriteProtected) MPRWriteProtected <= 1;
      else if (MPR[AddrRegister[18:16]][7:6] == 2'b11) MPRWriteProtected <= 1;
      else MPRWriteProtected <= 0;
   end
   
// -------------------------------------------------------------------------------------------------------
//      1.15:  Memory Partition Reg Write Operation Logic
// -------------------------------------------------------------------------------------------------------

   always @(posedge CS_N) begin
      if (HOLD_N == 1) begin
         if (InstructionWMPR & STATUS_WEL & STATUS_PREL & !WriteActive & !MPRWriteProtected) begin
            if (BitCounter == 40) begin
               MPRBuffer <= DataShifterI[07:00];
               ->MPR_WrEvent;
            end
         end
      end
   end
   
   always @(MPR_WrEvent) begin
      WriteActive = 1;
      #(tWC);
      WriteActive <= 0;
      STATUS_WEL <= 0;
      STATUS_PREL <= 0;
      // The endpoint address bits can only be modified if the Partition Address Boundary Protection (PABP)
      //   bit is not set
      MPR[AddrRegister[18:16]][7:6] <= MPRBuffer[7:6];
      if (!STATUS_PABP) MPR[AddrRegister[18:16]][5:0] <= MPRBuffer[5:0];
   end

// -------------------------------------------------------------------------------------------------------
//      1.16:  Protect Partition Address Boundaries Operation Logic
// -------------------------------------------------------------------------------------------------------

   always @(posedge CS_N) begin
      if (HOLD_N == 1) begin
         if (InstructionPPAB & STATUS_WEL & STATUS_PREL & !WriteActive & !HardwareWriteProtected) begin
            if ((BitCounter == 40) & (AddrRegister[15:00] == 16'hCC55)) begin
               if (DataShifterI[07:00] == 8'h00)
                  ->PPAB_ClearEvent;
               else if (DataShifterI[07:00] == 8'hFF)
                  ->PPAB_SetEvent;
            end
         end
      end
   end
   
   always @(PPAB_ClearEvent) begin
      WriteActive = 1;
      #(tWC);
      WriteActive <= 0;
      STATUS_WEL <= 0;
      STATUS_PREL <= 0;
      STATUS_PABP <= 0;
   end

   always @(PPAB_SetEvent) begin
      WriteActive = 1;
      #(tWC);
      WriteActive <= 0;
      STATUS_WEL <= 0;
      STATUS_PREL <= 0;
      STATUS_PABP <= 1;
   end

// -------------------------------------------------------------------------------------------------------
//      1.17:  Freeze Memory Protection Configuration Operation Logic
// -------------------------------------------------------------------------------------------------------

   always @(posedge CS_N) begin
      if (HOLD_N == 1) begin
         if (InstructionFRZR & STATUS_WEL & STATUS_PREL & !STATUS_FMPC & !WriteActive & !HardwareWriteProtected) begin
            if ((BitCounter == 40) & (AddrRegister[15:00] == 16'hAA40) & (DataShifterI[07:00] == 8'hD2)) begin
               ->FRZR_Event;
            end
         end
      end
   end
   
   always @(FRZR_Event) begin
      WriteActive = 1;
      #(tWC);
      WriteActive <= 0;
      STATUS_WEL <= 0;
      STATUS_PREL <= 0;
      STATUS_FMPC <= 1;
   end

// -------------------------------------------------------------------------------------------------------
//      1.18:  Output Data Shifter
// -------------------------------------------------------------------------------------------------------

   always @(negedge SCK) begin
      if (HOLD_N == 1) begin
         if (InstructionREAD & !WriteActive) begin
            if (BitCounter >= 32) begin
               if (BitCounter[2:0] == 0) begin
                  DataShifterO <= MemoryBlock[AddrRegister[18:00]];
                  AddrRegister <= AddrRegister + 19'd1;
                  SO_Enable <= 1;
               end
               else DataShifterO <= DataShifterO << 1;
            end
         end
         else if (InstructionRDSR) begin
            if (BitCounter >= 8) begin
               if (BitCounter[2:0] == 0) begin
                  if (BitCounter[3] == 1) begin
                     // BitCounter[3] == 1 corresponds to Status Reg MSB
                     DataShifterO <= {STATUS_WPEN,3'b000,STATUS_BP,STATUS_WEL,WriteActive};
                  end
                  else begin
                     // BitCounter[3] == 0 corresponds to Status Reg LSB
                     DataShifterO <= {STATUS_WPM,STATUS_ECS,STATUS_FMPC,STATUS_PREL,STATUS_PABP,2'b00,WriteActive};
                  end
                  SO_Enable <= 1;
               end
               else DataShifterO <= DataShifterO << 1;
            end
         end
         else if (InstructionWRBP) begin
            if (BitCounter >= 8) begin
               if (BitCounter[2:0] == 0) begin
                  DataShifterO <= {8{WriteActive}};
                  SO_Enable <= 1;
               end
               else DataShifterO <= DataShifterO << 1;
            end
         end
         else if (InstructionRDEX & !WriteActive) begin
            if (BitCounter >= 32) begin
               if (BitCounter[2:0] == 0) begin
                  DataShifterO <= SecurityReg[AddrRegister[08:00]];
                  AddrRegister[08:00] <= AddrRegister[08:00] + 9'd1;
                  SO_Enable <= 1;
               end
               else DataShifterO <= DataShifterO << 1;
            end
         end
         else if (InstructionCHLK & !WriteActive) begin
            if (BitCounter >= 32) begin
               if (BitCounter[2:0] == 0) begin
                  DataShifterO <= {8{SecRegLock}};
                  SO_Enable <= 1;
               end
               else DataShifterO <= DataShifterO << 1;
            end
         end
         else if (InstructionRMPR & !WriteActive) begin
            if (BitCounter >= 32) begin
               if (BitCounter[2:0] == 0) begin
                  DataShifterO <= (BitCounter == 32) ? MPR[AddrRegister[18:16]] : 8'hFF;
                  SO_Enable <= 1;
               end
               else DataShifterO <= DataShifterO << 1;
            end
         end
         else if (InstructionSPID & !WriteActive) begin
            if (BitCounter >= 8) begin
               if (BitCounter[2:0] == 0) begin
                  if (BitCounter <= 40) begin
                     DataShifterO <= MAN_ID[40-BitCounter +: 8];
                     SO_Enable <= 1;
                  end
                  else SO_Enable <= 0;
               end
               else DataShifterO <= DataShifterO << 1;
            end
         end
      end
   end

// -------------------------------------------------------------------------------------------------------
//      1.19:  Output Data Buffer
// -------------------------------------------------------------------------------------------------------

   bufif1 (SO, SO_DO, SO_OE);

   always @(DataShifterO) SO_DO <= #(tV) DataShifterO[07];

   bufif1 #(tV,0)    (OutputEnable1, SO_Enable, 1);
   notif1 #(tDIS)    (OutputEnable2, CS_N,   1);
   bufif1 #(tHV,tHZ) (OutputEnable3, HOLD_N, 1);

   assign SO_OE = OutputEnable1 & OutputEnable2 & OutputEnable3;


// *******************************************************************************************************
// **   LOGIC FUNCTIONS                                                                                 **
// *******************************************************************************************************
// -------------------------------------------------------------------------------------------------------
//      2.01:  FindMPR - Find applicable MPR for a given address
// -------------------------------------------------------------------------------------------------------

   function [07:00] FindMPR;
   
      input [23:00] Address;
      
      begin
         if (Address[18:13] <= MPR[0][5:0]) FindMPR = MPR[0];
         else if (Address[18:13] <= MPR[1][5:0]) FindMPR = MPR[1];
         else if (Address[18:13] <= MPR[2][5:0]) FindMPR = MPR[2];
         else if (Address[18:13] <= MPR[3][5:0]) FindMPR = MPR[3];
         else if (Address[18:13] <= MPR[4][5:0]) FindMPR = MPR[4];
         else if (Address[18:13] <= MPR[5][5:0]) FindMPR = MPR[5];
         else if (Address[18:13] <= MPR[6][5:0]) FindMPR = MPR[6];
         else if (Address[18:13] <= MPR[7][5:0]) FindMPR = MPR[7];
         else FindMPR = 8'h00;
      end
   endfunction


// *******************************************************************************************************
// **   DEBUG LOGIC                                                                                     **
// *******************************************************************************************************
// -------------------------------------------------------------------------------------------------------
//      3.01:  Memory Data Bytes
// -------------------------------------------------------------------------------------------------------

   wire [07:00] MemoryByte00000 = MemoryBlock[000000];
   wire [07:00] MemoryByte00001 = MemoryBlock[000001];
   wire [07:00] MemoryByte00002 = MemoryBlock[000002];
   wire [07:00] MemoryByte00003 = MemoryBlock[000003];
   wire [07:00] MemoryByte00004 = MemoryBlock[000004];
   wire [07:00] MemoryByte00005 = MemoryBlock[000005];
   wire [07:00] MemoryByte00006 = MemoryBlock[000006];
   wire [07:00] MemoryByte00007 = MemoryBlock[000007];
   wire [07:00] MemoryByte00008 = MemoryBlock[000008];
   wire [07:00] MemoryByte00009 = MemoryBlock[000009];
   wire [07:00] MemoryByte0000A = MemoryBlock[000010];
   wire [07:00] MemoryByte0000B = MemoryBlock[000011];
   wire [07:00] MemoryByte0000C = MemoryBlock[000012];
   wire [07:00] MemoryByte0000D = MemoryBlock[000013];
   wire [07:00] MemoryByte0000E = MemoryBlock[000014];
   wire [07:00] MemoryByte0000F = MemoryBlock[000015];

   wire [07:00] MemoryByte1FFF0 = MemoryBlock[131056];
   wire [07:00] MemoryByte1FFF1 = MemoryBlock[131057];
   wire [07:00] MemoryByte1FFF2 = MemoryBlock[131058];
   wire [07:00] MemoryByte1FFF3 = MemoryBlock[131059];
   wire [07:00] MemoryByte1FFF4 = MemoryBlock[131060];
   wire [07:00] MemoryByte1FFF5 = MemoryBlock[131061];
   wire [07:00] MemoryByte1FFF6 = MemoryBlock[131062];
   wire [07:00] MemoryByte1FFF7 = MemoryBlock[131063];
   wire [07:00] MemoryByte1FFF8 = MemoryBlock[131064];
   wire [07:00] MemoryByte1FFF9 = MemoryBlock[131065];
   wire [07:00] MemoryByte1FFFA = MemoryBlock[131066];
   wire [07:00] MemoryByte1FFFB = MemoryBlock[131067];
   wire [07:00] MemoryByte1FFFC = MemoryBlock[131068];
   wire [07:00] MemoryByte1FFFD = MemoryBlock[131069];
   wire [07:00] MemoryByte1FFFE = MemoryBlock[131070];
   wire [07:00] MemoryByte1FFFF = MemoryBlock[131071];

// -------------------------------------------------------------------------------------------------------
//      3.02:  Page Buffer Bytes
// -------------------------------------------------------------------------------------------------------

   wire [07:00] PageBuffer00 = PageBuffer[000];
   wire [07:00] PageBuffer01 = PageBuffer[001];
   wire [07:00] PageBuffer02 = PageBuffer[002];
   wire [07:00] PageBuffer03 = PageBuffer[003];
   wire [07:00] PageBuffer04 = PageBuffer[004];
   wire [07:00] PageBuffer05 = PageBuffer[005];
   wire [07:00] PageBuffer06 = PageBuffer[006];
   wire [07:00] PageBuffer07 = PageBuffer[007];
   wire [07:00] PageBuffer08 = PageBuffer[008];
   wire [07:00] PageBuffer09 = PageBuffer[009];
   wire [07:00] PageBuffer0A = PageBuffer[010];
   wire [07:00] PageBuffer0B = PageBuffer[011];
   wire [07:00] PageBuffer0C = PageBuffer[012];
   wire [07:00] PageBuffer0D = PageBuffer[013];
   wire [07:00] PageBuffer0E = PageBuffer[014];
   wire [07:00] PageBuffer0F = PageBuffer[015];

   wire [07:00] PageBuffer10 = PageBuffer[016];
   wire [07:00] PageBuffer11 = PageBuffer[017];
   wire [07:00] PageBuffer12 = PageBuffer[018];
   wire [07:00] PageBuffer13 = PageBuffer[019];
   wire [07:00] PageBuffer14 = PageBuffer[020];
   wire [07:00] PageBuffer15 = PageBuffer[021];
   wire [07:00] PageBuffer16 = PageBuffer[022];
   wire [07:00] PageBuffer17 = PageBuffer[023];
   wire [07:00] PageBuffer18 = PageBuffer[024];
   wire [07:00] PageBuffer19 = PageBuffer[025];
   wire [07:00] PageBuffer1A = PageBuffer[026];
   wire [07:00] PageBuffer1B = PageBuffer[027];
   wire [07:00] PageBuffer1C = PageBuffer[028];
   wire [07:00] PageBuffer1D = PageBuffer[029];
   wire [07:00] PageBuffer1E = PageBuffer[030];
   wire [07:00] PageBuffer1F = PageBuffer[031];

   wire [07:00] PageBufferE0 = PageBuffer[224];
   wire [07:00] PageBufferE1 = PageBuffer[225];
   wire [07:00] PageBufferE2 = PageBuffer[226];
   wire [07:00] PageBufferE3 = PageBuffer[227];
   wire [07:00] PageBufferE4 = PageBuffer[228];
   wire [07:00] PageBufferE5 = PageBuffer[229];
   wire [07:00] PageBufferE6 = PageBuffer[230];
   wire [07:00] PageBufferE7 = PageBuffer[231];
   wire [07:00] PageBufferE8 = PageBuffer[232];
   wire [07:00] PageBufferE9 = PageBuffer[233];
   wire [07:00] PageBufferEA = PageBuffer[234];
   wire [07:00] PageBufferEB = PageBuffer[235];
   wire [07:00] PageBufferEC = PageBuffer[236];
   wire [07:00] PageBufferED = PageBuffer[237];
   wire [07:00] PageBufferEE = PageBuffer[238];
   wire [07:00] PageBufferEF = PageBuffer[239];

   wire [07:00] PageBufferF0 = PageBuffer[240];
   wire [07:00] PageBufferF1 = PageBuffer[241];
   wire [07:00] PageBufferF2 = PageBuffer[242];
   wire [07:00] PageBufferF3 = PageBuffer[243];
   wire [07:00] PageBufferF4 = PageBuffer[244];
   wire [07:00] PageBufferF5 = PageBuffer[245];
   wire [07:00] PageBufferF6 = PageBuffer[246];
   wire [07:00] PageBufferF7 = PageBuffer[247];
   wire [07:00] PageBufferF8 = PageBuffer[248];
   wire [07:00] PageBufferF9 = PageBuffer[249];
   wire [07:00] PageBufferFA = PageBuffer[250];
   wire [07:00] PageBufferFB = PageBuffer[251];
   wire [07:00] PageBufferFC = PageBuffer[252];
   wire [07:00] PageBufferFD = PageBuffer[253];
   wire [07:00] PageBufferFE = PageBuffer[254];
   wire [07:00] PageBufferFF = PageBuffer[255];

// -------------------------------------------------------------------------------------------------------
//      3.03:  Security Register Bytes
// -------------------------------------------------------------------------------------------------------

   wire [07:00] SecRegByte000 = SecurityReg[000];
   wire [07:00] SecRegByte001 = SecurityReg[001];
   wire [07:00] SecRegByte002 = SecurityReg[002];
   wire [07:00] SecRegByte003 = SecurityReg[003];

   wire [07:00] SecRegByte0FC = SecurityReg[252];
   wire [07:00] SecRegByte0FD = SecurityReg[253];
   wire [07:00] SecRegByte0FE = SecurityReg[254];
   wire [07:00] SecRegByte0FF = SecurityReg[255];

   wire [07:00] SecRegByte100 = SecurityReg[256];
   wire [07:00] SecRegByte101 = SecurityReg[257];
   wire [07:00] SecRegByte102 = SecurityReg[258];
   wire [07:00] SecRegByte103 = SecurityReg[259];

   wire [07:00] SecRegByte1FC = SecurityReg[508];
   wire [07:00] SecRegByte1FD = SecurityReg[509];
   wire [07:00] SecRegByte1FE = SecurityReg[510];
   wire [07:00] SecRegByte1FF = SecurityReg[511];

// -------------------------------------------------------------------------------------------------------
//      3.04:  Memory Partition Register Bytes
// -------------------------------------------------------------------------------------------------------

   wire [07:00] MPR00 = MPR[00];
   wire [07:00] MPR01 = MPR[01];
   wire [07:00] MPR02 = MPR[02];
   wire [07:00] MPR03 = MPR[03];
   wire [07:00] MPR04 = MPR[04];
   wire [07:00] MPR05 = MPR[05];
   wire [07:00] MPR06 = MPR[06];
   wire [07:00] MPR07 = MPR[07];

// *******************************************************************************************************
// **   TIMING CHECKS                                                                                   **
// *******************************************************************************************************

   wire TimingCheckEnable = (RESET == 0) & (CS_N == 0);

   specify
      `ifdef VCC_2_5V_TO_3_0V
         specparam
            tHI  =  80,                                 // SCK pulse width - high
            tLO  =  80,                                 // SCK pulse width - low
            tSU  =  20,                                 // SI to SCK setup time
            tHD  =  20,                                 // SI to SCK hold time
            tHS  =  20,                                 // HOLD_N to SCK setup time
            tHH  =  20,                                 // HOLD_N to SCK hold time
            tCSD =  60,                                 // CS_N disable time
            tCSS =  60,                                 // CS_N to SCK setup time
            tCSH = 60,                                  // CS_N to SCK hold time
            tCLD = 50,                                  // Clock delay time
            tCLE = 50;                                  // Clock enable time
      `else
      `ifdef VCC_3_0V_TO_5_5V
         specparam
            tHI  =  40,                                 // SCK pulse width - high
            tLO  =  40,                                 // SCK pulse width - low
            tSU  =  10,                                 // SI to SCK setup time
            tHD  =  10,                                 // SI to SCK hold time
            tHS  =  10,                                 // HOLD_N to SCK setup time
            tHH  =  10,                                 // HOLD_N to SCK hold time
            tCSD =  30,                                 // CS_N disable time
            tCSS =  30,                                 // CS_N to SCK setup time
            tCSH =  30,                                 // CS_N to SCK hold time
            tCLD = 50,                                  // Clock delay time
            tCLE = 50;                                  // Clock enable time
      `else
         specparam
            tHI  =  40,                                 // SCK pulse width - high
            tLO  =  40,                                 // SCK pulse width - low
            tSU  =  10,                                 // SI to SCK setup time
            tHD  =  10,                                 // SI to SCK hold time
            tHS  =  10,                                 // HOLD_N to SCK setup time
            tHH  =  10,                                 // HOLD_N to SCK hold time
            tCSD =  30,                                 // CS_N disable time
            tCSS =  30,                                 // CS_N to SCK setup time
            tCSH =  30,                                 // CS_N to SCK hold time
            tCLD = 50,                                  // Clock delay time
            tCLE = 50;                                  // Clock enable time
      `endif
      `endif

      $width (posedge SCK,  tHI);
      $width (negedge SCK,  tLO);
      $width (posedge CS_N, tCSD);

      $setup (SI, posedge SCK &&& TimingCheckEnable, tSU);
      $setup (negedge CS_N, posedge SCK &&& TimingCheckEnable, tCSS);
      $setup (negedge SCK, negedge HOLD_N &&& TimingCheckEnable, tHS);
      $setup (posedge CS_N, posedge SCK &&& TimingCheckEnable, tCLD);

      $hold  (posedge SCK    &&& TimingCheckEnable, SI,   tHD);
      $hold  (posedge SCK    &&& TimingCheckEnable, posedge CS_N, tCSH);
      $hold  (posedge HOLD_N &&& TimingCheckEnable, posedge SCK,  tHH);
      $hold  (posedge SCK    &&& TimingCheckEnable, negedge CS_N, tCLE);
  endspecify
endmodule
