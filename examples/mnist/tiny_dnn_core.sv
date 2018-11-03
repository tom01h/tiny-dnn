module tiny_dnn_core
  (
   input wire       clk,
   input wire       init,
   input wire       write,
   input wire       bwrite,
   input wire       exec,
   input wire       bias,
   input wire [8:0] a,
   input real       d,
   input real       wd,
   output real      sum
   );

   parameter f_size = 512;

   real          W [0:f_size-1];
   real          w;
   reg           exec1,bias1;

   wire [8:0]    adr = (bwrite|bias) ? f_size-1 : a ;

   always_ff @(posedge clk)begin
      if(write)begin
         W[adr] <= wd;
      end
      if(exec|bias)begin
         w <= W[adr];
      end
      exec1 <= exec;
      bias1 <= bias;
      if(init)begin
         sum <= 0;
      end
      if(exec1)begin
         sum <= sum + w * d;
      end
      if(bias1)begin
         sum <= sum + w;
      end
   end

endmodule
