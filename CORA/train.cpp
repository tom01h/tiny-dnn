/*
    Copyright (c) 2013, Taiga Nomi and the respective contributors
    All rights reserved.

    Use of this source code is governed by a BSD-style license that can be found
    in the LICENSE file.
*/

// verilator
#include "unistd.h"
#include "getopt.h"
#include "Vtiny_dnn_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#define VCD_PATH_LENGTH 256

vluint64_t main_time = 0;
vluint64_t vcdstart = 0;
vluint64_t vcdend = 10000;

VerilatedVcdC* tfp;
Vtiny_dnn_top* verilator_top;

void eval()
{
  verilator_top->S_AXI_ACLK = 0;
  verilator_top->eval();
  if((main_time>=vcdstart)&((main_time<vcdend)|(vcdend==0)))
    tfp->dump(main_time);

  main_time += 5;

  verilator_top->S_AXI_ACLK = 1;
  verilator_top->eval();
  if((main_time>=vcdstart)&((main_time<vcdend)|(vcdend==0)))
    tfp->dump(main_time);

  main_time += 5;

  return;
}
// verilator

int main(int argc, char **argv) {

// verilator
  char vcdfile[VCD_PATH_LENGTH];
  strncpy(vcdfile,"tmp.vcd",VCD_PATH_LENGTH);
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  tfp = new VerilatedVcdC;
  verilator_top = new Vtiny_dnn_top;
  verilator_top->trace(tfp, 99); // requires explicit max levels param
  tfp->open(vcdfile);
  main_time = 0;
// verilator

  verilator_top->S_AXI_ARESETN = 0;
  verilator_top->S_AXI_BREADY = 1;
  verilator_top->S_AXI_RREADY = 1;
  verilator_top->S_AXI_ARVALID = 0;
  verilator_top->S_AXI_AWVALID = 0;
  verilator_top->S_AXI_WVALID = 0;
  verilator_top->S_AXI_WSTRB = 0xf;
  eval();
  eval();
  verilator_top->S_AXI_ARESETN = 1;

  verilator_top->S_AXI_AWADDR = 0x40000800;
  verilator_top->S_AXI_AWVALID = 1;
  verilator_top->S_AXI_WDATA = 0x3f800000;
  verilator_top->S_AXI_WVALID = 1;

  eval();
  verilator_top->S_AXI_AWVALID = 0;
  verilator_top->S_AXI_WVALID = 0;

  eval();
  eval();

  verilator_top->S_AXI_ARVALID = 1;
  verilator_top->S_AXI_ARADDR =0x40000800;
  eval();
  verilator_top->S_AXI_ARVALID = 0;

  eval();
  eval();

  verilator_top->S_AXI_ARVALID = 1;
  verilator_top->S_AXI_ARADDR =0x40008000;
  eval();
  verilator_top->S_AXI_ARVALID = 0;

  eval();
  eval();

  verilator_top->S_AXI_AWADDR = 0x40008000;
  verilator_top->S_AXI_AWVALID = 1;
  verilator_top->S_AXI_WDATA = 0x3f800000;
  verilator_top->S_AXI_WVALID = 1;

  eval();
  verilator_top->S_AXI_AWVALID = 0;
  verilator_top->S_AXI_WVALID = 0;

  eval();
  eval();

  verilator_top->S_AXI_ARVALID = 1;
  verilator_top->S_AXI_ARADDR =0x40008004;
  eval();
  verilator_top->S_AXI_ARVALID = 0;

  eval();
  eval();

  verilator_top->S_AXI_AWADDR = 0x4000fffc;
  verilator_top->S_AXI_AWVALID = 1;
  verilator_top->S_AXI_WDATA = 0x00000000;
  verilator_top->S_AXI_WVALID = 1;

  eval();
  verilator_top->S_AXI_AWVALID = 0;
  verilator_top->S_AXI_WVALID = 0;

  eval();
  eval();

/*
    output wire        S_AXI_AWREADY,
    output wire        S_AXI_WREADY,
    output wire [1:0]  S_AXI_BRESP,
    output wire        S_AXI_BVALID,
    
    output wire        S_AXI_ARREADY,
    output wire [31:0] S_AXI_RDATA,
    output wire [1:0]  S_AXI_RRESP,
    output wire        S_AXI_RVALID,
  */

  delete verilator_top;
  tfp->close();
  return 0;
}
