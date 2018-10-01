module tiny_dnn_top
  (
   input wire  clk,
   input real  a,
   input real  b,
   output real x
   );

   always_ff @(posedge clk)begin
      x <= a * b;
   end

endmodule
