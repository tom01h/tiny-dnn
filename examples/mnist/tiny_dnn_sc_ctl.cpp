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
      int icl=(backprop.read()) ? id.read().to_uint() : 0;
      for(int ic=0; ic<=icl; ic++){
        for(int oc=0; oc<=od.read().to_uint(); oc++){
          kn.write(oc);
          int ksi=ks.read().to_uint();
          int fsl=(backprop.read()) ? ks.read().to_uint() :
            ((bwrite.read()) ? 0 : fs.read().to_uint()); // forward
          for(int fs=0; fs<=fsl; fs++){
            if(backprop.read()){
              prm_a.write(ic*(ksi+1) + ksi - fs);
            }else{
              prm_a.write(fs);
            }
            wait();
          }
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

  while(true){
    wait();
    if(s_init.read()){
      for(int iy=0; iy<=oh.read().to_uint(); iy++){
        int yy = (backprop.read()) ? iy-kh.read().to_uint() : iy;
        for(int ix=0; ix<=ow.read().to_uint(); ix++){
          int xx = (backprop.read()) ? ix-kw.read().to_uint() : ix;
          k_init.write(1);
          wait();
          k_init.write(0);
          for(int ic=0; ic<=id.read().to_uint(); ic++){
            for(int fy=0; fy<=kh.read().to_uint(); fy++){
              if(backprop.read()){
                if((yy+fy)<0){fy=-yy;}
                if((yy+fy)==(ih.read().to_uint()+1)){break;}
              }
              for(int fx=0; fx<=kw.read().to_uint(); fx++){
                if(backprop.read()){
                  if((xx+fx)<0){fx=-xx;}
                  if((xx+fx)==(iw.read().to_uint()+1)){break;}
                }
                int i=ic*is.read().to_uint()+
                  (yy+fy)*(iw.read().to_uint()+1)+(xx+fx);
                int w = ic*(ks.read().to_uint()+1)+
                  fy*(kw.read().to_uint()+1)+fx;

                ia.write(i);
                wa.write(w);
                exec.write(1);
                wait();
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
