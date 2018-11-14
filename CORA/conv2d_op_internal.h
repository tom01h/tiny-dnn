/*
    Copyright (c) 2013, Taiga Nomi and the respective contributors
    All rights reserved.

    Use of this source code is governed by a BSD-style license that can be found
    in the LICENSE file.
*/

extern int dnn_addr;
extern int dma_addr;
extern int src_addr;
extern int dst_addr;

#define REG(reg_addr) *(volatile int*)(reg_addr)

#pragma once

#include <chrono>    // for high_resolution_clock, NOLINT
std::chrono::high_resolution_clock::time_point cst;
std::chrono::high_resolution_clock::duration cft, cbt;

int cf=0;
int cb=0;

union{
  int i;
  float f;
} conv;

namespace tiny_dnn {
namespace kernels {

inline void conv2d_op_internal(const tensor_t &in_data,
                               const vec_t &W,
                               const vec_t &bias,
                               tensor_t &out_data,
                               const core::conv_params &params,
                               const bool parallelize) {
  cst = std::chrono::high_resolution_clock::now();


  size_t out_area    = params.out.area();
  size_t iw          = params.in_padded.width_;
  size_t ih          = params.in_padded.height_;
  size_t id          = params.in.depth_;
  size_t ow          = params.out.width_;
  size_t oh          = params.out.height_;
  size_t od          = params.out.depth_;
  size_t kw          = params.weight.width_;
  size_t kh          = params.weight.height_;
  size_t elem_stride = params.w_stride;
  size_t line_stride = iw * params.h_stride;

  // NOT supported parametor
  // params.tbl.is_connected
  // params.w_stride
  // params.h_stride
  if(in_data.size()>1){

    REG(dnn_addr+20) = iw*ih*id-1; //ss
    REG(dnn_addr+24) = id-1;       //id
    REG(dnn_addr+28) = iw*ih;      //is
    REG(dnn_addr+32) = ih-1;       //ih
    REG(dnn_addr+36) = iw-1;       //iw
    
    REG(dnn_addr+40) = ow*oh*od-1; //ds
    REG(dnn_addr+44) = od-1;       //od
    REG(dnn_addr+48) = ow*oh;      //os
    REG(dnn_addr+52) = oh-1;       //oh
    REG(dnn_addr+56) = ow-1;       //ow

    REG(dnn_addr+ 4) = kw*kh*id-1; //fs
    REG(dnn_addr+ 8) = kw*kh-1;    //ks
    REG(dnn_addr+12) = kh-1;       //kh
    REG(dnn_addr+16) = kw-1;       //kw


    /////////////////////////////////////////////////////////
    // Weight transfer
    // AXI DMA reset
    REG(dma_addr + 0x00) = 4;
    while (REG(dma_addr + 0x00) & 0x4); // Wait for reset finish

    // DMA Buffer
    for(size_t i=0;i<od*id*kh*kw;i++){
      conv.f = W[i];
      REG(src_addr+i*4) = conv.i;
    }

    REG(dnn_addr+ 0) = 0; // init
    REG(dnn_addr+ 0) = 2; // wwrite

    // AXI DMA transfer tx
    REG(dma_addr+ 0x00) = 1;
    REG(dma_addr+ 0x18) = 0x1c000000;
    REG(dma_addr+ 0x28) = od*id*kh*kw*4;

    while ((REG(dma_addr+ 0x04) & 0x3)==0); // Wait for the tx to finish

    /////////////////////////////////////////////////////////
    // Bias transfer
    // AXI DMA reset
    REG(dma_addr + 0x00) = 4;
    while (REG(dma_addr + 0x00) & 0x4); // Wait for reset finish

    // DMA Buffer
    for (size_t o = 0; o < od; o++) {
      if (params.has_bias) {
        conv.f = bias[o];
        REG(src_addr+o*4) = conv.i;
      }else{
        REG(src_addr+o*4) = 0;
      }
    }

    REG(dnn_addr+ 0) = 0; // init
    REG(dnn_addr+ 0) = 1; // bwrite

    // AXI DMA transfer tx
    REG(dma_addr+ 0x00) = 1;
    REG(dma_addr+ 0x18) = 0x1c000000;
    REG(dma_addr+ 0x28) = od*4;

    while ((REG(dma_addr+ 0x04) & 0x3)==0); // Wait for the tx to finish

    /////////////////////////////////////////////////////////
    // Run
    REG(dnn_addr+ 0) = 0;   // init
    REG(dnn_addr+ 0) = 4|8; // run|enbias

    for (size_t sample = 0; sample < in_data.size(); sample++) {
      const vec_t &in = in_data[sample];
      vec_t &a        = out_data[sample];

      // AXI DMA reset
      REG(dma_addr + 0x30) = 4;
      REG(dma_addr + 0x0) = 4;
      while (REG(dma_addr + 0x0) & 0x4); // Wait for reset finish

      /////////////////////////////////////////////////////////
      // in data
      for(size_t i=0;i<iw*ih*id;i++){
        conv.f = in[i];
        REG(src_addr+i*4) = conv.i;
      }

      // AXI DMA transfer rx
      REG(dma_addr+ 0x30) = 1;
      REG(dma_addr+ 0x48) = 0x1e000000;
      REG(dma_addr+ 0x58) = ow*oh*od*4;

      // AXI DMA transfer tx
      REG(dma_addr+ 0x00) = 1;
      REG(dma_addr+ 0x18) = 0x1c000000;
      REG(dma_addr+ 0x28) = iw*ih*id*4;

      // Wait for the tx to finish
      while ((REG(dma_addr+ 0x04) & 0x3)==0);

      // Wait for the rx to finish
      while ((REG(dma_addr+ 0x34) & 0x3)==0) ;

      for(size_t i=0;i<od*oh*ow;i++){
        conv.i = REG(dst_addr+i*4);
        a[i] = conv.f;
      }
    }

    REG(dnn_addr+ 0) = 0; // idle

  }else{
    for (size_t sample = 0; sample < in_data.size(); sample++) {
      const vec_t &in = in_data[sample];
      vec_t &a        = out_data[sample];
      for (size_t o = 0; o < od; o++) {
        float_t *pa = &a[params.out.get_index(0, 0, o)];
        for (size_t inc = 0; inc < id; inc++) {
          if (!params.tbl.is_connected(o, inc)) continue;
          size_t idx;
          idx                = params.weight.get_index(0, 0, id * o + inc);
          const float_t *pw  = &W[idx];
          idx                = params.in_padded.get_index(0, 0, inc);
          const float_t *pin = &in[idx];
          float_t *pout      = pa;
          for (size_t y = 0; y < oh; y++) {
            const float_t *pin_line = pin;
            for (size_t x = 0; x < ow; x++) {
              const float_t *pin_element = pin_line;
              const float_t *pw_element  = pw;
              float_t sum{0};
              // should be optimized for small kernel(3x3,5x5)
              for (size_t wy = 0; wy < kh; wy++) {    // NOLINT
                for (size_t wx = 0; wx < kw; wx++) {  // NOLINT
                  sum += pw_element[wx] * pin_element[wx];
                }
                pw_element += kw;
                pin_element += iw;
              }
              pout[x] += sum;
              pin_line += elem_stride;
            }
            pout += ow;
            pin += line_stride;
          }
        }
        if (params.has_bias) {
          vectorize::add(bias[o], out_area, pa);
        }
      }
    }
  }

  cft += std::chrono::high_resolution_clock::now() - cst;
  if(in_data.size()>1){
    if(++cf==3750) std::cout << "cov forward "
                             << std::chrono::duration_cast<std::chrono::milliseconds>(cft).count() << "ms elapsed"
                             << std::endl;
  }
}

/******************************************************************/

template <typename tensor_t, typename vec_t>
void conv2d_op_internal(const tensor_t &prev_out,
                        const vec_t &W,
                        tensor_t &dW,
                        tensor_t &db,
                        tensor_t &curr_delta,
                        tensor_t &prev_delta,
                        const core::conv_params &params,
                        const bool parallelize) {
  typedef typename vec_t::value_type float_t;

  cst = std::chrono::high_resolution_clock::now();

  size_t iw          = params.in_padded.width_;
  size_t ih          = params.in_padded.height_;
  size_t id          = params.in.depth_;
  size_t ow          = params.out.width_;
  size_t oh          = params.out.height_;
  size_t od          = params.out.depth_;
  size_t kw          = params.weight.width_;
  size_t kh          = params.weight.height_;

  REG(dnn_addr+20) = ow*oh*od-1; //ss
  REG(dnn_addr+24) = od-1;       //id
  REG(dnn_addr+28) = ow*oh;      //is
  REG(dnn_addr+32) = oh-1;       //ih
  REG(dnn_addr+36) = ow-1;       //iw
    
  REG(dnn_addr+40) = iw*ih*id-1; //ds
  REG(dnn_addr+44) = id-1;       //od
  REG(dnn_addr+48) = iw*ih;      //os
  REG(dnn_addr+52) = ih-1;       //oh
  REG(dnn_addr+56) = iw-1;       //ow

  REG(dnn_addr+ 4) = kw*kh*od-1; //fs
  REG(dnn_addr+ 8) = kw*kh-1;    //ks
  REG(dnn_addr+12) = kh-1;       //kh
  REG(dnn_addr+16) = kw-1;       //kw

  /////////////////////////////////////////////////////////
  // Weight transfer
  // AXI DMA reset
  REG(dma_addr + 0x00) = 4;
  while (REG(dma_addr + 0x00) & 0x4); // Wait for reset finish

  // DMA Buffer
  for(size_t i=0;i<od*id*kh*kw;i++){
    conv.f = W[i];
    REG(src_addr+i*4) = conv.i;
  }

  REG(dnn_addr+ 0) = 0|16; // init|backprop
  REG(dnn_addr+ 0) = 2|16; // wwrite|backprop

  // AXI DMA transfer tx
  REG(dma_addr+ 0x00) = 1;
  REG(dma_addr+ 0x18) = 0x1c000000;
  REG(dma_addr+ 0x28) = od*id*kh*kw*4;

  while ((REG(dma_addr+ 0x04) & 0x3)==0); // Wait for the tx to finish

  /////////////////////////////////////////////////////////
  // Run
  REG(dnn_addr+ 0) = 0|16; // init|backprop
  REG(dnn_addr+ 0) = 4|16; // run|backprop

  for (size_t sample = 0; sample < prev_out.size(); sample++) {
    const vec_t &in = curr_delta[sample];
    vec_t &a        = prev_delta[sample];

      // AXI DMA reset
      REG(dma_addr + 0x30) = 4;
      REG(dma_addr + 0x0) = 4;
      while (REG(dma_addr + 0x0) & 0x4); // Wait for reset finish

      /////////////////////////////////////////////////////////
      // in data
      for(size_t i=0;i<ow*oh*od;i++){
        conv.f = in[i];
        REG(src_addr+i*4) = conv.i;
      }

      // AXI DMA transfer rx
      REG(dma_addr+ 0x30) = 1;
      REG(dma_addr+ 0x48) = 0x1e000000;
      REG(dma_addr+ 0x58) = iw*ih*id*4;

      // AXI DMA transfer tx
      REG(dma_addr+ 0x00) = 1;
      REG(dma_addr+ 0x18) = 0x1c000000;
      REG(dma_addr+ 0x28) = ow*oh*od*4;

      // Wait for the tx to finish
      while ((REG(dma_addr+ 0x04) & 0x3)==0);

      // Wait for the rx to finish
      while ((REG(dma_addr+ 0x34) & 0x3)==0) ;

      for(size_t i=0;i<id*ih*iw;i++){
        conv.i = REG(dst_addr+i*4);
        a[i] = conv.f;
      }
  }

  REG(dnn_addr+ 0) = 0; // idle

  for (size_t sample = 0; sample < prev_out.size(); sample++) {
    // accumulate dw
    for (size_t inc = 0; inc < params.in.depth_; inc++) {
      for (size_t outc = 0; outc < params.out.depth_; outc++) {
        if (!params.tbl.is_connected(outc, inc)) continue;

        for (size_t wy = 0; wy < params.weight.height_; wy++) {
          for (size_t wx = 0; wx < params.weight.width_; wx++) {
            float_t dst{0};

            size_t idx           = 0;
            idx                  = params.in_padded.get_index(wx, wy, inc);
            const float_t *prevo = &prev_out[sample][idx];

            idx                  = params.out.get_index(0, 0, outc);
            const float_t *delta = &curr_delta[sample][idx];

            if (params.w_stride > 1) {
              for (size_t y = 0; y < params.out.height_; y++) {
                size_t prevo_idx =
                  y * params.in_padded.width_ * params.h_stride;
                size_t delta_idx = y * params.out.width_;

                for (size_t x = 0; x < params.out.width_; x++) {
                  dst += prevo[prevo_idx + x * params.w_stride] *
                         delta[delta_idx + x];
                }
              }
            } else {
              for (size_t y = 0; y < params.out.height_; y++) {
                dst += vectorize::dot(
                  prevo + y * params.in_padded.width_ * params.h_stride,
                  delta + y * params.out.width_, params.out.width_);
              }
            }

            idx = params.in.depth_ * outc + inc;
            dW[sample][params.weight.get_index(wx, wy, idx)] += dst;
          }
        }
      }
    }

    // accumulate db
    if (params.has_bias) {
      for (size_t outc = 0; outc < params.out.depth_; outc++) {
        size_t idx            = params.out.get_index(0, 0, outc);
        const float_t *delta  = &curr_delta[sample][idx];
        const float_t *deltaa = delta + params.out.width_ * params.out.height_;
        db[sample][outc] += std::accumulate(delta, deltaa, float_t{0});
      }
    }
  }
  cbt += std::chrono::high_resolution_clock::now() - cst;
  if(++cb==3750) std::cout << "cov back "
                           << std::chrono::duration_cast<std::chrono::milliseconds>(cbt).count() << "ms elapsed"
                           << std::endl;
}

}  // namespace kernels
}  // namespace tiny_dnn
