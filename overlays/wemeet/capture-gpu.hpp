// SPDX-License-Identifier: MIT
#pragma once

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>
#include <drm_fourcc.h>
#include <spa/buffer/buffer.h>
#include <spa/param/video/raw.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

namespace wemeet {

inline uint32_t drm_format(spa_video_format format) {
  switch (format) {
  case SPA_VIDEO_FORMAT_RGBA: return DRM_FORMAT_ABGR8888;
  case SPA_VIDEO_FORMAT_RGBx: return DRM_FORMAT_XBGR8888;
  case SPA_VIDEO_FORMAT_BGRA: return DRM_FORMAT_ARGB8888;
  case SPA_VIDEO_FORMAT_BGRx: return DRM_FORMAT_XRGB8888;
  default: return 0;
  }
}

struct GpuFormat {
  spa_video_format format;
  std::vector<uint64_t> modifiers;
};

// Owned by the capture worker. No GL objects or context enter Qt's render thread.
class GpuReader {
public:
  GpuReader() = default;
  GpuReader(const GpuReader &) = delete;
  GpuReader &operator=(const GpuReader &) = delete;
  ~GpuReader() {
    if (display_ == EGL_NO_DISPLAY) return;
    if (context_ != EGL_NO_CONTEXT) {
      eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, context_);
      glDeleteTextures(1, &output_);
      glDeleteTextures(1, &input_);
      glDeleteFramebuffers(1, &framebuffer_);
      glDeleteProgram(program_);
      eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
      eglDestroyContext(display_, context_);
    }
    // EGL displays can be shared with the host application; never eglTerminate it.
  }

  bool initialize(std::string &error) {
    auto platform = reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(eglGetProcAddress("eglGetPlatformDisplayEXT"));
    display_ = platform ? platform(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, nullptr) : EGL_NO_DISPLAY;
    EGLint major{}, minor{};
    if (display_ == EGL_NO_DISPLAY || !eglInitialize(display_, &major, &minor)) {
      error = "surfaceless EGL initialization failed";
      return false;
    }
    const char *extensions = eglQueryString(display_, EGL_EXTENSIONS);
    if (!extensions || !std::strstr(extensions, "EGL_EXT_image_dma_buf_import_modifiers")) {
      error = "EGL DMA-BUF modifier import unavailable";
      return false;
    }
    if (!eglBindAPI(EGL_OPENGL_ES_API)) {
      error = "EGL could not select OpenGL ES";
      return false;
    }
    const EGLint config_attributes[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT, EGL_NONE};
    EGLConfig config{};
    EGLint count{};
    if (!eglChooseConfig(display_, config_attributes, &config, 1, &count) || count != 1) {
      error = "EGL ES3 configuration unavailable";
      return false;
    }
    const EGLint attributes[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
    context_ = eglCreateContext(display_, config, EGL_NO_CONTEXT, attributes);
    if (context_ == EGL_NO_CONTEXT || !eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, context_)) {
      error = "EGL capture context creation failed";
      return false;
    }
    create_image_ = reinterpret_cast<PFNEGLCREATEIMAGEKHRPROC>(eglGetProcAddress("eglCreateImageKHR"));
    destroy_image_ = reinterpret_cast<PFNEGLDESTROYIMAGEKHRPROC>(eglGetProcAddress("eglDestroyImageKHR"));
    image_target_ = reinterpret_cast<PFNGLEGLIMAGETARGETTEXTURE2DOESPROC>(eglGetProcAddress("glEGLImageTargetTexture2DOES"));
    auto query = reinterpret_cast<PFNEGLQUERYDMABUFMODIFIERSEXTPROC>(eglGetProcAddress("eglQueryDmaBufModifiersEXT"));
    if (!create_image_ || !destroy_image_ || !image_target_ || !query) {
      error = "EGL DMA-BUF entry points unavailable";
      return false;
    }
    const char *gl_extensions = reinterpret_cast<const char *>(glGetString(GL_EXTENSIONS));
    external_ = gl_extensions && std::strstr(gl_extensions, "GL_OES_EGL_image_external_essl3");
    for (auto format : {SPA_VIDEO_FORMAT_BGRx, SPA_VIDEO_FORMAT_BGRA, SPA_VIDEO_FORMAT_RGBx, SPA_VIDEO_FORMAT_RGBA}) {
      EGLint total{};
      if (!query(display_, drm_format(format), 0, nullptr, nullptr, &total) || total <= 0) continue;
      std::vector<EGLuint64KHR> modifiers(total);
      std::vector<EGLBoolean> external_only(total);
      EGLint returned{};
      if (!query(display_, drm_format(format), total, modifiers.data(), external_only.data(), &returned)) continue;
      GpuFormat supported{format, {}};
      for (int i = 0; i < returned; ++i) {
        if (!external_only[i] || external_) supported.modifiers.push_back(modifiers[i]);
      }
      if (!supported.modifiers.empty()) formats_.push_back(std::move(supported));
    }
    if (formats_.empty()) {
      error = "EGL exports no importable RGB DMA-BUF modifiers";
      return false;
    }
    const char *vertex = "#version 300 es\n out vec2 uv; void main(){ vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2); uv=p; gl_Position=vec4(p*2.0-1.0,0.0,1.0); }";
    const char *fragment_external = "#version 300 es\n#extension GL_OES_EGL_image_external_essl3 : require\nprecision highp float; in vec2 uv; uniform samplerExternalOES source; out vec4 color; void main(){color=vec4(texture(source,uv).rgb,1.0);}";
    const char *fragment_2d = "#version 300 es\nprecision highp float; in vec2 uv; uniform sampler2D source; out vec4 color; void main(){color=vec4(texture(source,uv).rgb,1.0);}";
    GLuint vs = compile(GL_VERTEX_SHADER, vertex, error);
    GLuint fs = compile(GL_FRAGMENT_SHADER, external_ ? fragment_external : fragment_2d, error);
    if (!vs || !fs) {
      glDeleteShader(vs);
      glDeleteShader(fs);
      return false;
    }
    program_ = glCreateProgram();
    glAttachShader(program_, vs);
    glAttachShader(program_, fs);
    glLinkProgram(program_);
    glDeleteShader(vs);
    glDeleteShader(fs);
    GLint linked{};
    glGetProgramiv(program_, GL_LINK_STATUS, &linked);
    if (!linked) { error = "DMA-BUF readback shader link failed"; return false; }
    glGenTextures(1, &input_);
    glGenTextures(1, &output_);
    glGenFramebuffers(1, &framebuffer_);
    GLint maximum{};
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maximum);
    max_size_ = static_cast<uint32_t>(std::max(maximum, 0));
    std::fprintf(stderr, "[wemeet capture] EGL %s; %zu DMA-BUF formats\n", eglQueryString(display_, EGL_VENDOR), formats_.size());
    return true;
  }

  const std::vector<GpuFormat> &formats() const { return formats_; }

  bool read(const spa_buffer &buffer, const spa_video_info_raw &info, std::vector<uint8_t> &pixels, std::string &error) {
    if (!program_ || !buffer.n_data || buffer.n_data > 4 || info.size.width > max_size_ || info.size.height > max_size_) {
      error = "unsupported DMA-BUF plane count or dimensions";
      return false;
    }
    std::array<EGLint, 64> attributes{};
    size_t used{};
    auto add = [&](EGLint key, EGLint value) { attributes[used++] = key; attributes[used++] = value; };
    add(EGL_WIDTH, info.size.width);
    add(EGL_HEIGHT, info.size.height);
    add(EGL_LINUX_DRM_FOURCC_EXT, drm_format(info.format));
    constexpr EGLint fd_keys[] = {EGL_DMA_BUF_PLANE0_FD_EXT, EGL_DMA_BUF_PLANE1_FD_EXT, EGL_DMA_BUF_PLANE2_FD_EXT, EGL_DMA_BUF_PLANE3_FD_EXT};
    constexpr EGLint offset_keys[] = {EGL_DMA_BUF_PLANE0_OFFSET_EXT, EGL_DMA_BUF_PLANE1_OFFSET_EXT, EGL_DMA_BUF_PLANE2_OFFSET_EXT, EGL_DMA_BUF_PLANE3_OFFSET_EXT};
    constexpr EGLint pitch_keys[] = {EGL_DMA_BUF_PLANE0_PITCH_EXT, EGL_DMA_BUF_PLANE1_PITCH_EXT, EGL_DMA_BUF_PLANE2_PITCH_EXT, EGL_DMA_BUF_PLANE3_PITCH_EXT};
    constexpr EGLint lo_keys[] = {EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, EGL_DMA_BUF_PLANE1_MODIFIER_LO_EXT, EGL_DMA_BUF_PLANE2_MODIFIER_LO_EXT, EGL_DMA_BUF_PLANE3_MODIFIER_LO_EXT};
    constexpr EGLint hi_keys[] = {EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, EGL_DMA_BUF_PLANE1_MODIFIER_HI_EXT, EGL_DMA_BUF_PLANE2_MODIFIER_HI_EXT, EGL_DMA_BUF_PLANE3_MODIFIER_HI_EXT};
    for (uint32_t i = 0; i < buffer.n_data; ++i) {
      const auto &plane = buffer.data[i];
      if (plane.type != SPA_DATA_DmaBuf || plane.fd < 0 || plane.fd > std::numeric_limits<EGLint>::max() || !plane.chunk || plane.chunk->stride <= 0 ||
          uint64_t(plane.mapoffset) + plane.chunk->offset > std::numeric_limits<EGLint>::max()) {
        error = "invalid DMA-BUF plane layout";
        return false;
      }
      add(fd_keys[i], plane.fd);
      add(offset_keys[i], plane.mapoffset + plane.chunk->offset);
      add(pitch_keys[i], plane.chunk->stride);
      if (info.modifier != DRM_FORMAT_MOD_INVALID) {
        add(lo_keys[i], static_cast<uint32_t>(info.modifier));
        add(hi_keys[i], static_cast<uint32_t>(info.modifier >> 32));
      }
    }
    attributes[used] = EGL_NONE;
    EGLImageKHR image = create_image_(display_, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, nullptr, attributes.data());
    if (image == EGL_NO_IMAGE_KHR) {
      char message[96];
      std::snprintf(message, sizeof(message), "EGL DMA-BUF import failed: 0x%x", eglGetError());
      error = message;
      return false;
    }
    const GLenum target = external_ ? GL_TEXTURE_EXTERNAL_OES : GL_TEXTURE_2D;
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(target, input_);
    glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    image_target_(target, image);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_);
    glBindTexture(GL_TEXTURE_2D, output_);
    if (width_ != info.size.width || height_ != info.size.height) {
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, info.size.width, info.size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
      width_ = info.size.width;
      height_ = info.size.height;
    }
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, output_, 0);
    bool success = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
    if (success) {
      if (!external_) glBindTexture(target, input_);
      glUseProgram(program_);
      glUniform1i(glGetUniformLocation(program_, "source"), 0);
      glViewport(0, 0, width_, height_);
      glDrawArrays(GL_TRIANGLES, 0, 3);
      pixels.resize(static_cast<size_t>(width_) * height_ * 4);
      // DMA-BUF row zero is mapped to GL's row zero; both draw and read preserve it.
      glReadPixels(0, 0, width_, height_, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
      success = glGetError() == GL_NO_ERROR;
    }
    glBindTexture(target, 0);
    destroy_image_(display_, image);
    if (!success) error = "DMA-BUF render/readback failed";
    return success;
  }

private:
  static GLuint compile(GLenum type, const char *text, std::string &error) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &text, nullptr);
    glCompileShader(shader);
    GLint success{};
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (success) return shader;
    char message[512]{};
    glGetShaderInfoLog(shader, sizeof(message), nullptr, message);
    error = message;
    glDeleteShader(shader);
    return 0;
  }

  EGLDisplay display_{EGL_NO_DISPLAY};
  EGLContext context_{EGL_NO_CONTEXT};
  PFNEGLCREATEIMAGEKHRPROC create_image_{};
  PFNEGLDESTROYIMAGEKHRPROC destroy_image_{};
  PFNGLEGLIMAGETARGETTEXTURE2DOESPROC image_target_{};
  GLuint input_{}, output_{}, framebuffer_{}, program_{};
  uint32_t width_{}, height_{}, max_size_{};
  bool external_{};
  std::vector<GpuFormat> formats_;
};

} // namespace wemeet
