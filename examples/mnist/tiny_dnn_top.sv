module tiny_dnn_top
  (
   input wire        clk,
   input wire        write,
   input wire        init,
   input wire        exec,
   input wire [12:0] a,
   input real        w,
   input real        d,
   output real       x
   );

   parameter f_num  = 16;

   real          sum [0:15];

   always_ff @(posedge clk)begin
      x <= sum[a];
   end


   generate
      genvar i;
      for (i = 0; i < f_num; i = i + 1) begin
         tiny_dnn_core tiny_dnn_core
               (
                .clk(clk),
                .write(write&(a[12:9] == i)),
                .init(init),
                .exec(exec),
                .a(a[8:0]),
                .w(w),
                .d(d),
                .sum(sum[i])
                );
      end
   endgenerate

endmodule

module tiny_dnn_core
  (
   input wire       clk,
   input wire       write,
   input wire       init,
   input wire       exec,
   input wire [8:0] a,
   input real       w,
   input real       d,
   output real      sum
   );

   parameter f_size = 512;

   real          W [0:f_size-1];

   always_ff @(posedge clk)begin
      if(write)begin
         W[a] <= w;
      end
      if(init)begin
         sum <= 0;
      end
      if(exec)begin
         sum <= sum + W[a] * d;
      end
   end

endmodule
