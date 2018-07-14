/*
    Copyright (c) 2013, Taiga Nomi and the respective contributors
    All rights reserved.

    Use of this source code is governed by a BSD-style license that can be found
    in the LICENSE file.
*/
#pragma once

#include <limits>
#include <vector>

#include <chrono>    // for high_resolution_clock, NOLINT
std::chrono::high_resolution_clock::time_point pst;
std::chrono::high_resolution_clock::duration pft, pbt;

int pf=0;
int pb=0;

namespace tiny_dnn {
namespace kernels {

inline void maxpool_op_internal(const tensor_t &in_data,
                                tensor_t &out_data,
                                std::vector<std::vector<size_t>> &max_idx,
                                const std::vector<std::vector<size_t>> &out2in,
                                const bool layer_parallelize) {
  pst = std::chrono::high_resolution_clock::now();
  for_i(layer_parallelize, in_data.size(), [&](size_t sample) {
    const vec_t &in          = in_data[sample];
    vec_t &out               = out_data[sample];
    std::vector<size_t> &max = max_idx[sample];

    for (size_t i = 0; i < out2in.size(); i++) {
      const auto &in_index = out2in[i];
      float_t max_value    = std::numeric_limits<float_t>::lowest();
      size_t idx           = 0;
      for (auto j : in_index) {
        if (in[j] > max_value) {
          max_value = in[j];
          idx       = j;
        }
      }
      max[i] = idx;
      out[i] = max_value;
    }
  });
  pft += std::chrono::high_resolution_clock::now() - pst;
  if(in_data.size()>1){
    if(++pf==2500) std::cout << std::endl << "pool forward "
                             << std::chrono::duration_cast<std::chrono::milliseconds>(pft).count() << "ms elapsed"
                             << std::endl;
  }
}

inline void maxpool_grad_op_internal(tensor_t &prev_delta,
                                     const tensor_t &curr_delta,
                                     std::vector<std::vector<size_t>> &max_idx,
                                     const std::vector<size_t> &in2out,
                                     const bool layer_parallelize) {
  pst = std::chrono::high_resolution_clock::now();
  for_i(layer_parallelize, prev_delta.size(), [&](size_t sample) {
    vec_t &prev                    = prev_delta[sample];
    const vec_t &curr              = curr_delta[sample];
    const std::vector<size_t> &max = max_idx[sample];

    for (size_t i = 0; i < in2out.size(); i++) {
      size_t outi = in2out[i];
      prev[i]     = (max[outi] == i) ? curr[outi] : float_t{0};
    }
  });
  pbt += std::chrono::high_resolution_clock::now() - pst;
  if(++pb==2500) std::cout << "pool back "
                           << std::chrono::duration_cast<std::chrono::milliseconds>(pbt).count() << "ms elapsed"
                           << std::endl;
}

}  // namespace kernels
}  // namespace tiny_dnn
