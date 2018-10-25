/*
    Copyright (c) 2013, Taiga Nomi and the respective contributors
    All rights reserved.

    Use of this source code is governed by a BSD-style license that can be found
    in the LICENSE file.
*/
#include "Vtiny_dnn_top.h"
extern Vtiny_dnn_top* verilator_top;
extern void eval();

#pragma once

#include <chrono>    // for high_resolution_clock, NOLINT
std::chrono::high_resolution_clock::time_point cst;
std::chrono::high_resolution_clock::duration cft, cbt;

int cf=0;
int cb=0;

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
  size_t filter_size = 512;

  verilator_top->ss = iw*ih*id-1;
  verilator_top->id = id-1;
  verilator_top->is = iw*ih;
  verilator_top->ih = ih-1;
  verilator_top->iw = iw-1;
  verilator_top->ds = ow*oh*od-1;
  verilator_top->od = od-1;
  verilator_top->os = ow*oh;
  verilator_top->oh = oh-1;
  verilator_top->ow = ow-1;
  verilator_top->fs = kw*kh*id-1;
  verilator_top->kh = kh-1;
  verilator_top->kw = kw-1;


  verilator_top->wwrite = 0;
  verilator_top->bwrite = 0;
  verilator_top->run = 0;
  verilator_top->src_valid = 0;
  verilator_top->init = 1;//
  eval();
  verilator_top->init = 0;//

  verilator_top->wwrite = 1;
  for(size_t i=0;i<od*id*kh*kw;i++){
    verilator_top->src_data = (double)W[i];
    eval();
  }
  verilator_top->wwrite = 0;
  verilator_top->init = 1;//
  eval();
  verilator_top->init = 0;//

  verilator_top->bwrite = 1;
  for (size_t o = 0; o < od; o++) {
    if (params.has_bias) {
      verilator_top->src_data = (double)bias[o];
    }else{
      verilator_top->src_data = (double)0;
    }
    eval();
  }
  verilator_top->bwrite = 0;

  // NOT supported parametor
  // params.tbl.is_connected
  // params.w_stride
  // params.h_stride
  if(in_data.size()>1){
    for (size_t sample = 0; sample < in_data.size(); sample++) {
      const vec_t &in = in_data[sample];
      vec_t &a        = out_data[sample];

      //   input wire         src_valid,
      //   input real         src_data,
      //   input wire         src_last,
      //   output wire        src_ready,

      verilator_top->src_valid = 1;
      for(size_t i=0;i<iw*ih*id;i++){
        verilator_top->src_data = in[i];
        eval();
      }
      verilator_top->src_valid = 0;

      while(!verilator_top->dst_valid) {
        eval();
      }
      
      for(size_t i=0;verilator_top->dst_valid;i++){
        a[i] = (float)verilator_top->dst_data;
        eval();
      }

    }
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
  for_i(parallelize, prev_out.size(), [&](size_t sample) {
    // propagate delta to previous layer
    for (size_t inc = 0; inc < params.in.depth_; inc++) {
      for (size_t outc = 0; outc < params.out.depth_; outc++) {
        if (!params.tbl.is_connected(outc, inc)) continue;

        size_t idx        = 0;
        idx               = params.in.depth_ * outc + inc;
        idx               = params.weight.get_index(0, 0, idx);
        const float_t *pw = &W[idx];

        idx                       = params.out.get_index(0, 0, outc);
        const float_t *pdelta_src = &curr_delta[sample][idx];

        idx = params.in_padded.get_index(0, 0, inc);
        // float_t* pdelta_dst = &(*prev_delta)[sample][idx];
        float_t *pdelta_dst = &prev_delta[sample][idx];

        for (size_t y = 0; y < params.out.height_; y++) {
          for (size_t x = 0; x < params.out.width_; x++) {
            const float_t *ppw = pw;

            idx                       = y * params.out.width_ + x;
            const float_t ppdelta_src = pdelta_src[idx];

            float_t *ppdelta_dst =
              pdelta_dst + y * params.h_stride * params.in_padded.width_ +
              x * params.w_stride;

            for (size_t wy = 0; wy < params.weight.height_; wy++) {   // NOLINT
              for (size_t wx = 0; wx < params.weight.width_; wx++) {  // NOLINT
                idx = wy * params.in_padded.width_ + wx;
                ppdelta_dst[idx] += *ppw++ * ppdelta_src;
              }
            }
          }
        }
      }
    }

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
  });
  cbt += std::chrono::high_resolution_clock::now() - cst;
  if(++cb==3750) std::cout << "cov back "
                           << std::chrono::duration_cast<std::chrono::milliseconds>(cbt).count() << "ms elapsed"
                           << std::endl;
}

}  // namespace kernels
}  // namespace tiny_dnn
