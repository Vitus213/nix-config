// SPDX-License-Identifier: MIT
#include "capture-frame.hpp"
#include <array>
#include <cstdio>
#include <cstdlib>

namespace {
void require(bool valid, const char *message) {
  if (!valid) { std::fprintf(stderr, "%s\n", message); std::exit(1); }
}
XImage image_for(std::vector<uint8_t> &pixels, int width, int height, int padding = 0) {
  XImage image{};
  image.width = width; image.height = height;
  image.bits_per_pixel = 32; image.byte_order = LSBFirst;
  image.bytes_per_line = width * 4 + padding;
  image.red_mask = 0xff; image.green_mask = 0xff00; image.blue_mask = 0xff0000;
  pixels.assign(size_t(image.bytes_per_line) * height + 16, 0x9d);
  image.data = reinterpret_cast<char *>(pixels.data());
  return image;
}
}

int main() {
  wemeet::Frame frame;
  frame.width = 5; frame.height = 4;
  frame.crop_x = 1; frame.crop_y = 1; frame.crop_width = 3; frame.crop_height = 2;
  frame.pixels.assign(frame.width * frame.height * 4, 0xee);
  for (uint32_t y = 0; y < 2; ++y) for (uint32_t x = 0; x < 3; ++x) {
    auto *pixel = frame.pixels.data() + ((y + 1) * frame.width + x + 1) * 4;
    pixel[0] = 1 + y * 3 + x; pixel[1] = 77; pixel[2] = 91; pixel[3] = 255;
  }
  const std::array<std::array<uint8_t, 6>, 8> expected{{
    {{1,2,3,4,5,6}}, {{3,6,2,5,1,4}}, {{6,5,4,3,2,1}}, {{4,1,5,2,6,3}},
    {{3,2,1,6,5,4}}, {{1,4,2,5,3,6}}, {{4,5,6,1,2,3}}, {{6,3,5,2,4,1}}
  }};
  for (uint32_t transform = 0; transform < 8; ++transform) {
    frame.transform = transform;
    std::vector<uint8_t> pixels;
    auto image = image_for(pixels, transform & 1 ? 2 : 3, transform & 1 ? 3 : 2, 8);
    require(frame.render(image), "valid crop/transform rejected");
    for (int y = 0; y < image.height; ++y) for (int x = 0; x < image.width; ++x) {
      const auto *pixel = pixels.data() + y * image.bytes_per_line + x * 4;
      require(pixel[0] == expected[transform][y * image.width + x] && pixel[1] == 77 && pixel[2] == 91 && pixel[3] == 255,
        "crop, rotation, reflection or channel order incorrect");
    }
    for (size_t i = size_t(image.bytes_per_line) * image.height; i < pixels.size(); ++i)
      require(pixels[i] == 0x9d, "render wrote beyond XImage extent");
  }
  frame.transform = SPA_META_TRANSFORMATION_None;
  std::vector<uint8_t> pixels;
  auto image = image_for(pixels, 6, 6, 4);
  image.red_mask = 0xff0000; image.blue_mask = 0xff;
  require(frame.render(image), "valid BGRA image rejected");
  require(pixels[0] == 0 && pixels[image.bytes_per_line * 5] == 0, "letterboxing not cleared");
  const auto *first = pixels.data() + image.bytes_per_line;
  require(first[0] == 91 && first[1] == 77 && first[2] == 1 && first[3] == 255, "BGRA channel conversion incorrect");
  image.bytes_per_line = 3;
  require(!frame.render(image), "short XImage stride accepted");
  std::puts("frame crop, eight transforms, channel order, padding and letterbox checks passed");
}
