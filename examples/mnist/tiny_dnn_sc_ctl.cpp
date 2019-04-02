#include "tiny_dnn_sc_ctl.h"

void tiny_dnn_sc_ctl::exect()
{
  //Initialization
  s_fin.write(0);
  k_init.write(0);
  k_fin.write(0);
  exec.write(0);
  ia.write(0);
  wa.write(0);

  wait();

  while(true){
    wait();
    if(s_init.read()){
      for(int dc=0; dc<=dd.read(); dc++){
        for(int iy=0; iy<=oh.read(); iy++){
          int yy = (backprop.read()) ? iy-kh.read() : iy;
          for(int ix=0; ix<=ow.read(); ix++){
            int xx = (backprop.read()) ? ix-kw.read() : ix;
            k_init.write(1);
            wait();
            k_init.write(0);
            for(int ic=0; ic<=id.read(); ic++){
              for(int fy=0; fy<=kh.read(); fy++){
                if(backprop.read()){
                  if((yy+fy)<0){fy=-yy;}
                  if((yy+fy)==(ih.read()+1)){break;}
                }
                for(int fx=0; fx<=kw.read(); fx++){
                  if(backprop.read()){
                    if((xx+fx)<0){fx=-xx;}
                    if((xx+fx)==(iw.read()+1)){break;}
                  }
                  int i=dc*is.read()+ic*is.read()+
                    (yy+fy)*(iw.read()+1)+(xx+fx);
                  int w = ic*(ks.read()+1)+
                    fy*(kw.read()+1)+fx;

                  ia.write(i);
                  wa.write(w);
                  exec.write(1);
                  wait();
                }
              }
            }
            exec.write(0);
            k_fin.write(1);
            wait();
            k_fin.write(0);
            wait();
            while(out_busy.read()){
              wait();
            }
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
