// SPDX-License-Identifier: MIT
#pragma once

#include <X11/Xlib.h>
#include <spa/buffer/meta.h>
#include <spa/param/video/raw.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <vector>

namespace wemeet {

struct Frame {
  std::vector<uint8_t> pixels; // tightly packed RGBA, original top-to-bottom order
  uint32_t width{}, height{};
  uint32_t crop_x{}, crop_y{}, crop_width{}, crop_height{};
  uint32_t transform{SPA_META_TRANSFORMATION_None};

  bool render(XImage &image) const {
    if (pixels.empty() || !width || !height || !crop_width || !crop_height || !image.data || image.width <= 0 || image.height <= 0 ||
        image.bits_per_pixel != 32 || image.byte_order != LSBFirst || image.bytes_per_line < int64_t(image.width) * 4 ||
        image.green_mask != 0xff00 || !((image.red_mask == 0xff0000 && image.blue_mask == 0xff) ||
                                      (image.red_mask == 0xff && image.blue_mask == 0xff0000))) return false;
    const uint32_t rotation = transform & 3;
    const bool flipped = transform >= SPA_META_TRANSFORMATION_Flipped;
    const uint32_t visible_width = rotation & 1 ? crop_height : crop_width;
    const uint32_t visible_height = rotation & 1 ? crop_width : crop_height;
    uint32_t target_width = image.width;
    uint32_t target_height = image.height;
    if (uint64_t(visible_width) * target_height > uint64_t(visible_height) * target_width)
      target_height = std::max<uint32_t>(1, uint64_t(target_width) * visible_height / visible_width);
    else
      target_width = std::max<uint32_t>(1, uint64_t(target_height) * visible_width / visible_height);
    const uint32_t left = (image.width - target_width) / 2;
    const uint32_t top = (image.height - target_height) / 2;
    std::memset(image.data, 0, size_t(image.bytes_per_line) * image.height);
    const uint64_t step_x = (uint64_t(visible_width) << 32) / target_width;
    const uint64_t step_y = (uint64_t(visible_height) << 32) / target_height;
    uint64_t position_y = step_y / 2;
    for (uint32_t y = 0; y < target_height; ++y, position_y += step_y) {
      const uint32_t sy = std::min<uint32_t>(position_y >> 32, visible_height - 1);
      auto *output = reinterpret_cast<uint8_t *>(image.data) + size_t(top + y) * image.bytes_per_line + size_t(left) * 4;
      uint64_t position_x = step_x / 2;
      for (uint32_t x = 0; x < target_width; ++x, position_x += step_x, output += 4) {
        const uint32_t sx = std::min<uint32_t>(position_x >> 32, visible_width - 1);
        uint32_t source_x{}, source_y{};
        // Undo the producer's flip-then-counterclockwise-rotation transform.
        switch (rotation) {
        case 0: source_x = sx; source_y = sy; break;
        case 1: source_x = crop_width - sy - 1; source_y = sx; break;
        case 2: source_x = crop_width - sx - 1; source_y = crop_height - sy - 1; break;
        default: source_x = sy; source_y = crop_height - sx - 1; break;
        }
        if (flipped) source_x = crop_width - source_x - 1;
        const auto *input = pixels.data() + (size_t(crop_y + source_y) * width + crop_x + source_x) * 4;
        output[0] = input[image.red_mask == 0xff ? 0 : 2];
        output[1] = input[1];
        output[2] = input[image.red_mask == 0xff ? 2 : 0];
        output[3] = 255;
      }
    }
    return true;
  }
};

} // namespace wemeet
