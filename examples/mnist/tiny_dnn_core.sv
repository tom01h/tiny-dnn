module tiny_dnn_core
  (
   input wire       clk,
   input wire       init,
   input wire       write,
   input wire       bwrite,
   input wire       exec,
   input wire       sum_ip,
   input wire       sum_op,
   input wire       bias,
   input wire [9:0] ra,
   input wire [9:0] wa,
   input real       d,
   input real       wd,
   output real      sum
   );

   parameter f_size = 1024;

   real          W [0:f_size-1];
   real          w, w1, d1;
   reg           init1,exec1,bias1, init2,exec2,bias2;

   wire [9:0]    radr = (bias)   ? f_size-1 : ra ;
   wire [9:0]    wadr = (bwrite) ? f_size-1 : wa ;

   real          sumi [1:0];
   assign sum = sumi[sum_op];

   always_ff @(posedge clk)begin
      if(write)begin
         W[wadr] <= wd;
      end
      if(exec|bias)begin
         w <= W[radr];
      end
      if(exec1|bias1)begin
         w1 <= w;
         d1 <= d;
      end
      init1 <= init;
      exec1 <= exec;
      bias1 <= bias;
      init2 <= init1;
      exec2 <= exec1;
      bias2 <= bias1;
      if(init2)begin
         sumi[sum_ip] <= 0;
      end
      if(exec2)begin
         sumi[sum_ip] <= sumi[sum_ip] + w1 * d1;
      end
      if(bias2)begin
         sumi[sum_ip] <= sumi[sum_ip] + w1;
      end
   end

endmodule
