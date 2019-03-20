#include "tiny_dnn_sc_ctl.h"

void tiny_dnn_sc_ctl::exect()
{
  //Initialization
  ia.write(0);
  wa.write(0);
  k_init.write(0);
  exec.write(0);
  k_fin.write(0);

  k_fin_i=0;

  wait();

  int i=0;
  int w=0;

  while(true){
    wait();
    if(s_init.read() && i==0){
      for(int iy=0; iy<28-4; iy++){
        for(int ix=0; ix<28-4; ix++){
          k_init.write(1);
          wait();
          k_init.write(0);
          for(int fy=0; fy<5; fy++){
            for(int fx=0; fx<5; fx++){
              i=(iy+fy)*28+(ix+fx);
              ia.write(i);
              wa.write(w);
              exec.write(1);
              wait();
              w++;
            }
          }
          exec.write(0);
          w=0;
          k_fin.write(1);
          k_fin_i=1;
          k_base=iy*24+ix;
          wait();
          k_fin.write(0);
          k_fin_i=0;
          while(!o_fin_i){
            wait();
          }
        }
      }
    }
  }
}

void tiny_dnn_sc_ctl::outt()
{
  //Initialization
  outc.write(0);
  oa.write(0);
  o_fin.write(0);

  o_fin_i=0;

  while(true){
    wait();
    if(k_fin_i){
      for(int i=0; i<6; i++){
        outc.write(i);
        oa.write(i*576+k_base);
        wait();
      }
      o_fin.write(1);
      o_fin_i=1;
      wait();
      o_fin.write(0);
      o_fin_i=0;
    }
  }
}
