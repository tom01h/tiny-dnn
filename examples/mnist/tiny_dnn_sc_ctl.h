#include <systemc.h>

SC_MODULE(tiny_dnn_sc_ctl)
{
  //Ports
  sc_in  <bool>         clk;
  sc_in  <bool>         backprop;
  sc_in  <bool>         run;
  sc_in  <bool>         wwrite;
  sc_in  <bool>         bwrite;
  sc_in  <bool>         s_init;
  sc_out <bool>         s_fin;
  sc_out <bool>         k_init;
  sc_out <bool>         k_fin;
  sc_out <bool>         exec;
  sc_out <sc_bv<13> >   ia;
  sc_out <bool>         outr;
  sc_out <sc_bv<13> >   oa;
  sc_out <sc_bv<4> >    kn;
  sc_out <sc_bv<10> >   wa;
  sc_out <sc_bv<4> >    ra;
  sc_out <sc_bv<10> >   prm_a;

  sc_in <bool>          src_valid;
  sc_in <bool>          src_ready;

  sc_in <sc_bv<4> >     dd;
  sc_in <sc_bv<4> >     id;
  sc_in <sc_bv<10> >    is;
  sc_in <sc_bv<5> >     ih;
  sc_in <sc_bv<5> >     iw;
  sc_in <sc_bv<4> >     od;
  sc_in <sc_bv<10> >    os;
  sc_in <sc_bv<5> >     oh;
  sc_in <sc_bv<5> >     ow;
  sc_in <sc_bv<10> >    fs;
  sc_in <sc_bv<10> >    ks;
  sc_in <sc_bv<5> >     kh;
  sc_in <sc_bv<5> >     kw;

  //Variables
  bool         k_fin_i;
  bool         o_fin_i;
  int          k_base;

  //Thread Declaration
  void writet();
  void exect();
  void nrmt();
  void outt();

  //Constructor
  SC_CTOR(tiny_dnn_sc_ctl)
  {
    SC_CTHREAD(writet,clk.pos());
    SC_CTHREAD(exect,clk.pos());
    SC_CTHREAD(nrmt,clk.pos());
    SC_CTHREAD(outt,clk.pos());

  }
};
