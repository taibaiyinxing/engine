// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FLOW_LAYERS_OPACITY_LAYER_H_
#define FLUTTER_FLOW_LAYERS_OPACITY_LAYER_H_

#include "flutter/flow/layers/container_layer.h"

namespace flow {

class OpacityLayer : public ContainerLayer {
 public:
  OpacityLayer();
  ~OpacityLayer() override;

  void set_alpha(int alpha) { alpha_ = alpha; }

  void Paint(PaintContext& context) const override;

  // TODO(chinmaygarde): Once MZ-139 is addressed, introduce a new node in the
  // session scene hierarchy.

 private:
  int alpha_;

  FML_DISALLOW_COPY_AND_ASSIGN(OpacityLayer);
};

}  // namespace flow

#endif  // FLUTTER_FLOW_LAYERS_OPACITY_LAYER_H_
