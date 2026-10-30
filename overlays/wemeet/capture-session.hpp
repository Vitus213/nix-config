// SPDX-License-Identifier: MIT
#pragma once

// EGL and GLES declarations must precede Xlib's macro definitions.
#include "capture-gpu.hpp"
#include "capture-frame.hpp"
#include "capture-portal.hpp"
#include <pipewire/pipewire.h>
#include <spa/param/video/format-utils.h>
#include <spa/pod/builder.h>
#include <spa/utils/result.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <thread>
#include <utility>
#include <unistd.h>

namespace wemeet {

class Capture {
public:
  Capture() = default;
  Capture(const Capture &) = delete;
  Capture &operator=(const Capture &) = delete;
  ~Capture() { stop(); }

  bool start() {
    std::unique_lock<std::mutex> lock(mutex_);
    if (!worker_.joinable() && !stop_.load()) worker_ = std::thread([this] { run(); });
    changed_.wait(lock, [this] { return frames_ || finished_ || stop_.load(); });
    return frames_ && !finished_ && !stop_.load();
  }

  void stop() {
    std::thread worker;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      stop_.store(true);
      changed_.notify_all();
      worker = std::move(worker_);
    }
    if (worker.joinable()) worker.join();
  }

  bool render(XImage &image) {
    std::lock_guard<std::mutex> lock(mutex_);
    return !stop_.load() && !finished_ && frame_.render(image);
  }

  std::string error() {
    std::lock_guard<std::mutex> lock(mutex_);
    return error_;
  }

  uint64_t frame_count() {
    std::lock_guard<std::mutex> lock(mutex_);
    return frames_;
  }


private:
  void fail(std::string message) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (error_.empty()) error_ = std::move(message);
    stop_.store(true);
    changed_.notify_all();
  }


  void connect_pipewire(int fd) {
    loop_ = pw_main_loop_new(nullptr);
    if (!loop_) { if (fd >= 0) close(fd); fail("PipeWire loop creation failed"); return; }
    context_ = pw_context_new(pw_main_loop_get_loop(loop_), nullptr, 0);
    if (!context_) { if (fd >= 0) close(fd); fail("PipeWire context creation failed"); return; }
    core_ = fd >= 0 ? pw_context_connect_fd(context_, fd, nullptr, 0) : pw_context_connect(context_, nullptr, 0);
    if (!core_) { fail("PipeWire connection failed"); return; }
    static const pw_core_events core_events = [] {
      pw_core_events events{};
      events.version = PW_VERSION_CORE_EVENTS;
      events.error = [](void *data, uint32_t, int, int, const char *message) {
        static_cast<Capture *>(data)->fail(message ? message : "PipeWire core error");
      };
      return events;
    }();
    pw_core_add_listener(core_, &core_listener_, &core_events, this);
    registry_ = pw_core_get_registry(core_, PW_VERSION_REGISTRY, 0);
    static const pw_registry_events registry_events = [] {
      pw_registry_events events{};
      events.version = PW_VERSION_REGISTRY_EVENTS;
      events.global = [](void *data, uint32_t id, uint32_t, const char *type, uint32_t, const spa_dict *props) {
        auto &self = *static_cast<Capture *>(data);
        if (id != self.node_id_ || self.stream_ || std::strcmp(type, PW_TYPE_INTERFACE_Node) != 0) return;
        const char *serial = props ? spa_dict_lookup(props, PW_KEY_OBJECT_SERIAL) : nullptr;
        if (!serial) { self.fail("selected PipeWire node has no serial"); return; }
        self.connect_stream(serial);
      };
      events.global_remove = [](void *data, uint32_t id) {
        auto &self = *static_cast<Capture *>(data);
        if (id == self.node_id_) self.fail("selected screen stream disappeared");
      };
      return events;
    }();
    pw_registry_add_listener(registry_, &registry_listener_, &registry_events, this);
  }

  spa_pod *build_format(spa_pod_builder &builder, spa_video_format format, const std::vector<uint64_t> *modifiers) {
    spa_pod_frame object{}, choice{};
    spa_pod_builder_push_object(&builder, &object, SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat);
    const spa_rectangle preferred = SPA_RECTANGLE(1920, 1080);
    const spa_rectangle minimum = SPA_RECTANGLE(1, 1);
    const spa_rectangle maximum = SPA_RECTANGLE(8192, 8192);
    const spa_fraction rate = SPA_FRACTION(30, 1);
    const spa_fraction zero = SPA_FRACTION(0, 1);
    spa_pod_builder_add(&builder,
      SPA_FORMAT_mediaType, SPA_POD_Id(SPA_MEDIA_TYPE_video),
      SPA_FORMAT_mediaSubtype, SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
      SPA_FORMAT_VIDEO_format, SPA_POD_Id(format),
      SPA_FORMAT_VIDEO_size, SPA_POD_CHOICE_RANGE_Rectangle(&preferred, &minimum, &maximum),
      SPA_FORMAT_VIDEO_framerate, SPA_POD_CHOICE_RANGE_Fraction(&rate, &zero, &rate), 0);
    if (modifiers && !modifiers->empty()) {
      spa_pod_builder_prop(&builder, SPA_FORMAT_VIDEO_modifier, SPA_POD_PROP_FLAG_MANDATORY | SPA_POD_PROP_FLAG_DONT_FIXATE);
      spa_pod_builder_push_choice(&builder, &choice, SPA_CHOICE_Enum, 0);
      spa_pod_builder_long(&builder, modifiers->front());
      for (auto modifier : *modifiers) spa_pod_builder_long(&builder, modifier);
      spa_pod_builder_pop(&builder, &choice);
    }
    return static_cast<spa_pod *>(spa_pod_builder_pop(&builder, &object));
  }

  void connect_stream(const char *serial) {
    pw_properties *properties = pw_properties_new(PW_KEY_TARGET_OBJECT, serial, PW_KEY_MEDIA_TYPE, "Video", PW_KEY_MEDIA_CATEGORY, "Capture", PW_KEY_MEDIA_ROLE, "Screen", nullptr);
    stream_ = pw_stream_new(core_, "Tencent Meeting desktop capture", properties);
    if (!stream_) { fail("PipeWire stream creation failed"); return; }
    static const pw_stream_events events = [] {
      pw_stream_events value{};
      value.version = PW_VERSION_STREAM_EVENTS;
      value.state_changed = [](void *data, pw_stream_state, pw_stream_state state, const char *error) {
        if (state == PW_STREAM_STATE_ERROR) static_cast<Capture *>(data)->fail(error ? error : "PipeWire stream error");
      };
      value.param_changed = [](void *data, uint32_t id, const spa_pod *param) { static_cast<Capture *>(data)->format_changed(id, param); };
      value.process = [](void *data) { static_cast<Capture *>(data)->process(); };
      value.remove_buffer = [](void *data, pw_buffer *buffer) {
        auto &self = *static_cast<Capture *>(data);
        if (self.pending_ == buffer) self.pending_ = nullptr;
      };
      return value;
    }();
    pw_stream_add_listener(stream_, &stream_listener_, &events, this);
    size_t size = 4096;
    for (const auto &format : gpu_->formats()) size += format.modifiers.size() * 16;
    std::vector<uint8_t> storage(size);
    spa_pod_builder builder = SPA_POD_BUILDER_INIT(storage.data(), static_cast<uint32_t>(storage.size()));
    std::vector<const spa_pod *> formats;
    formats.reserve(gpu_->formats().size() + 4);
    for (const auto &format : gpu_->formats()) formats.push_back(build_format(builder, format.format, &format.modifiers));
    for (auto format : {SPA_VIDEO_FORMAT_BGRx, SPA_VIDEO_FORMAT_BGRA, SPA_VIDEO_FORMAT_RGBx, SPA_VIDEO_FORMAT_RGBA})
      formats.push_back(build_format(builder, format, nullptr));
    if (std::any_of(formats.begin(), formats.end(), [](auto pod) { return !pod; })) { fail("PipeWire format serialization failed"); return; }
    int status = pw_stream_connect(stream_, PW_DIRECTION_INPUT, PW_ID_ANY,
      pw_stream_flags(PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_MAP_BUFFERS), formats.data(), formats.size());
    if (status < 0) fail(std::string("PipeWire connect failed: ") + spa_strerror(status));
  }

  void format_changed(uint32_t id, const spa_pod *param) {
    if (id != SPA_PARAM_Format || !param) return;
    spa_video_info_raw format{};
    if (spa_format_video_raw_parse(param, &format) < 0 || !drm_format(format.format) || !format.size.width || !format.size.height ||
        format.size.width > 8192 || format.size.height > 8192) { fail("invalid or unsupported screen format"); return; }
    if (pending_) { pw_stream_queue_buffer(stream_, pending_); pending_ = nullptr; }
    info_ = format;
    const bool dma = spa_pod_find_prop(param, nullptr, SPA_FORMAT_VIDEO_modifier);
    if (!dma) info_.modifier = DRM_FORMAT_MOD_INVALID;
    uint8_t storage[1024];
    spa_pod_builder builder = SPA_POD_BUILDER_INIT(storage, sizeof(storage));
    const spa_pod *parameters[] = {
      static_cast<spa_pod *>(spa_pod_builder_add_object(&builder, SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
        SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(4, 2, 16),
        SPA_PARAM_BUFFERS_dataType, SPA_POD_CHOICE_FLAGS_Int(dma ? 1 << SPA_DATA_DmaBuf : (1 << SPA_DATA_MemFd) | (1 << SPA_DATA_MemPtr)))),
      static_cast<spa_pod *>(spa_pod_builder_add_object(&builder, SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
        SPA_PARAM_META_type, SPA_POD_Id(SPA_META_VideoCrop), SPA_PARAM_META_size, SPA_POD_Int(sizeof(spa_meta_region)))),
      static_cast<spa_pod *>(spa_pod_builder_add_object(&builder, SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
        SPA_PARAM_META_type, SPA_POD_Id(SPA_META_VideoTransform), SPA_PARAM_META_size, SPA_POD_Int(sizeof(spa_meta_videotransform))))
    };
    pw_stream_update_params(stream_, parameters, 3);
    std::fprintf(stderr, "[wemeet capture] negotiated %ux%u format=%u modifier=0x%llx %s\n", info_.size.width, info_.size.height,
      info_.format, static_cast<unsigned long long>(info_.modifier), dma ? "DMA-BUF" : "SHM");
  }

  bool copy_memory(const spa_buffer &buffer, std::vector<uint8_t> &pixels) {
    if (buffer.n_datas != 1) return false;
    const auto &plane = buffer.datas[0];
    if ((plane.type != SPA_DATA_MemFd && plane.type != SPA_DATA_MemPtr) || !plane.data || !plane.chunk || !plane.maxsize) return false;
    const size_t row_bytes = size_t(info_.size.width) * 4;
    const size_t offset = plane.chunk->offset % plane.maxsize;
    const int64_t stride = plane.chunk->stride;
    const int64_t last = int64_t(offset) + int64_t(info_.size.height - 1) * stride;
    if (std::abs(stride) < int64_t(row_bytes) || last < 0 || offset + row_bytes > plane.maxsize || uint64_t(last) + row_bytes > plane.maxsize ||
        plane.chunk->size < uint64_t(info_.size.height - 1) * std::abs(stride) + row_bytes) return false;
    pixels.resize(row_bytes * info_.size.height);
    const bool bgra = info_.format == SPA_VIDEO_FORMAT_BGRA || info_.format == SPA_VIDEO_FORMAT_BGRx;
    for (uint32_t y = 0; y < info_.size.height; ++y) {
      const auto *source = static_cast<const uint8_t *>(plane.data) + int64_t(offset) + int64_t(y) * stride;
      auto *target = pixels.data() + y * row_bytes;
      for (uint32_t x = 0; x < info_.size.width; ++x, source += 4, target += 4) {
        target[0] = source[bgra ? 2 : 0]; target[1] = source[1]; target[2] = source[bgra ? 0 : 2]; target[3] = 255;
      }
    }
    return true;
  }

  void process() {
    while (auto *next = pw_stream_dequeue_buffer(stream_)) {
      if (pending_) pw_stream_queue_buffer(stream_, pending_);
      pending_ = next;
    }
    consume_pending();
  }

  void consume_pending() {
    if (!pending_ || stop_.load()) return;
    const auto now = std::chrono::steady_clock::now();
    if (now - last_frame_ < std::chrono::milliseconds(33)) return;
    last_frame_ = now;
    auto *selected = std::exchange(pending_, nullptr);
    const auto &buffer = *selected->buffer;
    if (!info_.size.width || !buffer.n_datas || !buffer.datas[0].chunk ||
        (buffer.datas[0].chunk->flags & (SPA_CHUNK_FLAG_CORRUPTED | SPA_CHUNK_FLAG_EMPTY))) {
      pw_stream_queue_buffer(stream_, selected);
      return;
    }
    std::string error;
    const bool dma = buffer.datas[0].type == SPA_DATA_DmaBuf;
    const bool copied = dma ? gpu_->read(buffer, info_, staging_, error) : copy_memory(buffer, staging_);
    if (copied) {
      std::lock_guard<std::mutex> lock(mutex_);
      frame_.pixels.swap(staging_);
      frame_.width = info_.size.width; frame_.height = info_.size.height;
      frame_.crop_x = frame_.crop_y = 0; frame_.crop_width = frame_.width; frame_.crop_height = frame_.height;
      const auto *crop = static_cast<spa_meta_region *>(spa_buffer_find_meta_data(&buffer, SPA_META_VideoCrop, sizeof(spa_meta_region)));
      if (crop && spa_meta_region_is_valid(crop)) {
        const auto &region = crop->region;
        if (region.position.x >= 0 && region.position.y >= 0 && uint64_t(region.position.x) + region.size.width <= frame_.width &&
            uint64_t(region.position.y) + region.size.height <= frame_.height) {
          frame_.crop_x = region.position.x; frame_.crop_y = region.position.y;
          frame_.crop_width = region.size.width; frame_.crop_height = region.size.height;
        }
      }
      const auto *transform = static_cast<spa_meta_videotransform *>(spa_buffer_find_meta_data(&buffer, SPA_META_VideoTransform, sizeof(spa_meta_videotransform)));
      frame_.transform = transform && transform->transform <= SPA_META_TRANSFORMATION_Flipped270 ? transform->transform : uint32_t(SPA_META_TRANSFORMATION_None);
      ++frames_;
      changed_.notify_all();
    }
    pw_stream_queue_buffer(stream_, selected);
    if (!copied) fail(error.empty() ? "invalid shared-memory frame layout" : error);
  }

  void run() {
    GMainContext *main = g_main_context_new();
    g_main_context_push_thread_default(main);
    static std::once_flag initialized;
    std::call_once(initialized, [] { pw_init(nullptr, nullptr); });
    gpu_ = std::make_unique<GpuReader>();
    std::string gpu_error;
    // SHM remains available if this host cannot import DMA-BUF.
    if (!gpu_->initialize(gpu_error)) {
      std::fprintf(stderr, "[wemeet capture] %s; offering SHM only\n", gpu_error.c_str());
      gpu_.reset();
      gpu_ = std::make_unique<GpuReader>();
    }
    portal_ = std::make_unique<ScreenPortal>();
    std::string error;
    if (portal_->open(stop_, main, error)) {
      node_id_ = portal_->node();
      int fd = portal_->open_remote(error);
      if (fd >= 0) connect_pipewire(fd);
      else fail(error);
    } else fail(error);
    while (!stop_.load()) {
      while (g_main_context_iteration(main, false)) {}
      if (portal_ && portal_->closed()) fail("portal session closed");
      if (loop_ && !stop_.load()) {
        int status = pw_loop_iterate(pw_main_loop_get_loop(loop_), 10);
        if (status < 0 && status != -EINTR) fail(std::string("PipeWire loop failed: ") + spa_strerror(status));
        consume_pending();
      } else {
        std::unique_lock<std::mutex> lock(mutex_);
        changed_.wait_for(lock, std::chrono::milliseconds(10));
      }
    }
    if (pending_) { pw_stream_queue_buffer(stream_, pending_); pending_ = nullptr; }
    if (stream_) { spa_hook_remove(&stream_listener_); pw_stream_destroy(stream_); stream_ = nullptr; }
    if (registry_) { spa_hook_remove(&registry_listener_); pw_proxy_destroy(reinterpret_cast<pw_proxy *>(registry_)); registry_ = nullptr; }
    if (core_) { spa_hook_remove(&core_listener_); pw_core_disconnect(core_); core_ = nullptr; }
    if (context_) { pw_context_destroy(context_); context_ = nullptr; }
    if (loop_) { pw_main_loop_destroy(loop_); loop_ = nullptr; }
    portal_.reset();
    while (g_main_context_iteration(main, false)) {}
    gpu_.reset();
    g_main_context_pop_thread_default(main);
    g_main_context_unref(main);
    {
      std::lock_guard<std::mutex> lock(mutex_);
      finished_ = true;
      changed_.notify_all();
      std::fprintf(stderr, "[wemeet capture] stopped after %llu frames%s%s\n", static_cast<unsigned long long>(frames_), error_.empty() ? "" : ": ", error_.c_str());
    }
  }

  std::mutex mutex_;
  std::condition_variable changed_;
  std::atomic<bool> stop_{};
  bool finished_{};
  std::string error_;
  Frame frame_;
  std::vector<uint8_t> staging_;
  uint64_t frames_{};
  std::chrono::steady_clock::time_point last_frame_{};
  std::thread worker_;
  std::unique_ptr<GpuReader> gpu_;
  std::unique_ptr<ScreenPortal> portal_;
  uint32_t node_id_{PW_ID_ANY};
  pw_main_loop *loop_{};
  pw_context *context_{};
  pw_core *core_{};
  pw_registry *registry_{};
  pw_stream *stream_{};
  pw_buffer *pending_{};
  spa_hook core_listener_{}, registry_listener_{}, stream_listener_{};
  spa_video_info_raw info_{};
};

} // namespace wemeet
