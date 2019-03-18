#include <systemc.h>

SC_MODULE(tiny_dnn_sc_ctl)
{
  //Ports
  sc_in  <bool>         clk;
  sc_in  <bool>         s_init;
  sc_out <bool>         k_init;
  //sc_out <sc_uint<13> > ia;
  //sc_out <sc_uint<10> > wa;
  sc_out <uint32_t >    ia;
  sc_out <uint32_t >    wa;

  //Variables

  //Process Declaration
  void Prc1();

  //Constructor
  SC_CTOR(tiny_dnn_sc_ctl)
  {
    //Process Registration
    SC_CTHREAD(Prc1,clk.pos());
    //reset_signal_is(reset,true);

  }
};
