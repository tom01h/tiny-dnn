module tiny_dnn_core
  (
   input wire       clk,
   input wire       init,
   input wire       write,
   input wire       bwrite,
   input wire       exec,
   input wire       bias,
   input wire [9:0] ra,
   input wire [9:0] wa,
   input real       d,
   input real       wd,
   output real      sum
   );

   parameter f_size = 1024;

   real          W [0:f_size-1];
   real          w;
   reg           exec1,bias1;

   wire [9:0]    radr = (bias)   ? f_size-1 : ra ;
   wire [9:0]    wadr = (bwrite) ? f_size-1 : wa ;

   always_ff @(posedge clk)begin
      if(write)begin
         W[wadr] <= wd;
      end
      if(exec|bias)begin
         w <= W[radr];
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
