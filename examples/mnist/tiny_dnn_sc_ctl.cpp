#include "tiny_dnn_sc_ctl.h"

void tiny_dnn_sc_ctl::writet()
{
  //Initialization
  kn.write(0);
  prm_a.write(0);

  wait();

  while(true){
    wait();
    if(wwrite.read() || bwrite.read()){
      for(int oc=0; oc<=od.read().to_uint(); oc++){
        kn.write(oc);
        int fsl=(bwrite.read()) ? 0 : fs.read().to_uint();
        for(int fs=0; fs<=fsl; fs++){
          prm_a.write(fs);
          wait();
        }
      }
      while(wwrite.read() || bwrite.read()){
        wait();
      }
    }
  }
}

void tiny_dnn_sc_ctl::exect()
{
  //Initialization
  s_fin.write(0);
  k_init.write(0);
  k_fin.write(0);
  exec.write(0);
  ia.write(0);
  wa.write(0);

  k_fin_i=0;

  wait();

  int i=0;
  int w=0;

  while(true){
    wait();
    if(s_init.read()){
      for(int iy=0; iy<=oh.read().to_uint(); iy++){
        for(int ix=0; ix<=ow.read().to_uint(); ix++){
          k_init.write(1);
          wait();
          k_init.write(0);
          w=0;
          for(int ic=0; ic<=id.read().to_uint(); ic++){
            for(int fy=0; fy<=kh.read().to_uint(); fy++){
              for(int fx=0; fx<=kw.read().to_uint(); fx++){
                i=ic*is.read().to_uint()+
                  (iy+fy)*(iw.read().to_uint()+1)+(ix+fx);
                ia.write(i);
                wa.write(w);
                exec.write(1);
                wait();
                w++;
              }
            }
          }
          exec.write(0);
          k_fin.write(1);
          k_fin_i=1;
          k_base=iy*(ow.read().to_uint()+1)+ix;
          wait();
          k_fin.write(0);
          k_fin_i=0;
          while(!o_fin_i){
            wait();
          }
        }
      }
      wait();
      s_fin.write(1);
      wait();
      s_fin.write(0);
    }
  }
}

void tiny_dnn_sc_ctl::nrmt()
{
  //Initialization
  o_fin_i=0;

  while(true){
    wait();
    if(k_fin_i){
      for(int i=0; i<=od.read().to_uint(); i++){
        wait();
      }
      o_fin_i=1;
      wait();
      o_fin_i=0;
    }
  }
}

void tiny_dnn_sc_ctl::outt()
{
  //Initialization
  outr.write(0);
  oa.write(0);
  ra.write(0);

  while(true){
    wait();
    if(k_fin_i){
      wait();
      for(int i=0; i<=od.read().to_uint(); i++){
        outr.write(1);
        oa.write(i*os.read().to_uint()+k_base);
        ra.write(i);
        wait();
      }
      outr.write(0);
    }
  }
}
