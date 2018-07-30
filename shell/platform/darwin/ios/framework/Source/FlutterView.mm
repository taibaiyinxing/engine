// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/darwin/ios/framework/Source/FlutterView.h"

#include "flutter/common/settings.h"
#include "flutter/common/task_runners.h"
#include "flutter/flow/layers/layer_tree.h"
#include "flutter/fml/platform/darwin/cf_utils.h"
#include "flutter/fml/synchronization/waitable_event.h"
#include "flutter/fml/trace_event.h"
#include "flutter/shell/common/platform_view.h"
#include "flutter/shell/common/rasterizer.h"
#include "flutter/shell/common/shell.h"
#include "flutter/shell/platform/darwin/ios/framework/Source/FlutterViewController_Internal.h"
#include "flutter/shell/platform/darwin/ios/ios_surface_gl.h"
#include "flutter/shell/platform/darwin/ios/ios_surface_software.h"
#include "third_party/skia/include/utils/mac/SkCGUtils.h"

@interface FlutterView () <UIInputViewAudioFeedback>

@end

@implementation FlutterView

- (FlutterViewController*)flutterViewController {
  // Find the first view controller in the responder chain and see if it is a FlutterViewController.
  for (UIResponder* responder = self.nextResponder; responder != nil;
       responder = responder.nextResponder) {
    if ([responder isKindOfClass:[UIViewController class]]) {
      if ([responder isKindOfClass:[FlutterViewController class]]) {
        return reinterpret_cast<FlutterViewController*>(responder);
      } else {
        // Should only happen if a non-FlutterViewController tries to somehow (via dynamic class
        // resolution or reparenting) set a FlutterView as its view.
        return nil;
      }
    }
  }
  return nil;
}

- (void)layoutSubviews {
  if ([self.layer isKindOfClass:[CAEAGLLayer class]]) {
    CAEAGLLayer* layer = reinterpret_cast<CAEAGLLayer*>(self.layer);
    layer.allowsGroupOpacity = YES;
    layer.opaque = YES;
    CGFloat screenScale = [UIScreen mainScreen].scale;
    layer.contentsScale = screenScale;
    layer.rasterizationScale = screenScale;
  }

  [super layoutSubviews];
}

+ (Class)layerClass {
#if TARGET_IPHONE_SIMULATOR
  return [CALayer class];
#else   // TARGET_IPHONE_SIMULATOR
  return [CAEAGLLayer class];
#endif  // TARGET_IPHONE_SIMULATOR
}

- (std::unique_ptr<shell::IOSSurface>)createSurface {
  if ([self.layer isKindOfClass:[CAEAGLLayer class]]) {
    fml::scoped_nsobject<CAEAGLLayer> eagl_layer(
        reinterpret_cast<CAEAGLLayer*>([self.layer retain]));
    return std::make_unique<shell::IOSSurfaceGL>(std::move(eagl_layer));
  } else {
    fml::scoped_nsobject<CALayer> layer(reinterpret_cast<CALayer*>([self.layer retain]));
    return std::make_unique<shell::IOSSurfaceSoftware>(std::move(layer));
  }
}

- (BOOL)enableInputClicksWhenVisible {
  return YES;
}

- (void)drawLayer:(CALayer*)layer inContext:(CGContextRef)context {
  TRACE_EVENT0("flutter", "SnapshotFlutterView");

  if (layer != self.layer || context == nullptr) {
    return;
  }

  FlutterViewController* controller = [self flutterViewController];

  if (controller == nil) {
    return;
  }

  auto& shell = [controller shell];

  auto screenshot = shell.Screenshot(shell::Rasterizer::ScreenshotType::UncompressedImage,
                                     false /* base64 encode */);

  if (!screenshot.data || screenshot.data->isEmpty() || screenshot.frame_size.isEmpty()) {
    return;
  }

  NSData* data = [NSData dataWithBytes:const_cast<void*>(screenshot.data->data())
                                length:screenshot.data->size()];

  fml::CFRef<CGDataProviderRef> image_data_provider(
      CGDataProviderCreateWithCFData(reinterpret_cast<CFDataRef>(data)));

  fml::CFRef<CGColorSpaceRef> colorspace(CGColorSpaceCreateDeviceRGB());

  fml::CFRef<CGImageRef> image(CGImageCreate(
      screenshot.frame_size.width(),      // size_t width
      screenshot.frame_size.height(),     // size_t height
      8,                                  // size_t bitsPerComponent
      32,                                 // size_t bitsPerPixel,
      4 * screenshot.frame_size.width(),  // size_t bytesPerRow
      colorspace,                         // CGColorSpaceRef space
      static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast |
                                kCGBitmapByteOrder32Big),  // CGBitmapInfo bitmapInfo
      image_data_provider,                                 // CGDataProviderRef provider
      nullptr,                                             // const CGFloat* decode
      false,                                               // bool shouldInterpolate
      kCGRenderingIntentDefault                            // CGColorRenderingIntent intent
      ));

  const CGRect frame_rect =
      CGRectMake(0.0, 0.0, screenshot.frame_size.width(), screenshot.frame_size.height());

  CGContextSaveGState(context);
  CGContextTranslateCTM(context, 0.0, CGBitmapContextGetHeight(context));
  CGContextScaleCTM(context, 1.0, -1.0);
  CGContextDrawImage(context, frame_rect, image);
  CGContextRestoreGState(context);
}

@end
