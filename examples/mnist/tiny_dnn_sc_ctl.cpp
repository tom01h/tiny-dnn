#include "tiny_dnn_sc_ctl.h"

void tiny_dnn_sc_ctl::Prc1()
{
  //Initialization
  ia.write(0);
  wa.write(0);
  k_init.write(0);
  wait();

  int i=0;
  int w=0;
  while(true){
    wait();
    if(s_init.read() && i==0){
      k_init.write(1);
      wait();
      k_init.write(0);
      for(int iy=0; iy<28-4; iy++){
        for(int ix=0; ix<28-4; ix++){
          for(int fy=0; fy<5; fy++){
            for(int fx=0; fx<5; fx++){
              i=(iy+fy)*28+(ix+fx);
              ia.write(i);
              wa.write(w);
              wait();
              w++;
            }
          }
          w=0;
          for(i=0; i<7; i++){
            wait();
          }
          k_init.write(1);
          wait();
          k_init.write(0);
        }
      }
    }else{
      ia.write(0);
    }
  }
}
