#include <systemc.h>

SC_MODULE(tiny_dnn_sc_ctl)
{
  //Ports
  sc_in  <bool>         clk;
  sc_in  <bool>         s_init;
  sc_out <bool>         k_init;
  sc_out <bool>         exec;
  sc_out <bool>         k_fin;
  sc_out <bool>         o_fin;
  sc_out <sc_bv<4> >    outc;
  sc_out <sc_bv<13> >   ia;
  sc_out <sc_bv<10> >   wa;
  sc_out <sc_bv<13> >   oa;

  //Variables
  bool         k_fin_i;
  bool         o_fin_i;
  int          k_base;

  //Thread Declaration
  void exect();
  void outt();

  //Constructor
  SC_CTOR(tiny_dnn_sc_ctl)
  {
    SC_CTHREAD(exect,clk.pos());
    SC_CTHREAD(outt,clk.pos());

  }
};
