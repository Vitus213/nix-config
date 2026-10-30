// SPDX-License-Identifier: MIT
#include "capture-session.hpp"
#include <X11/extensions/XShm.h>
#include <dlfcn.h>

#include <map>

namespace {
std::mutex sessions_mutex;
struct Session {
  std::shared_ptr<wemeet::Capture> capture;
  Display *display;
  char *address;
};
std::map<ShmSeg, Session> sessions;

bool enabled() {
  const char *value = std::getenv("WEMEET_WAYLAND_CAPTURE");
  return value && std::strcmp(value, "1") == 0;
}

template <typename Function> Function original(const char *name) {
  return reinterpret_cast<Function>(dlsym(RTLD_NEXT, name));
}
}

extern "C" Bool XShmAttach(Display *display, XShmSegmentInfo *segment) {
  static const auto attach = original<decltype(&XShmAttach)>("XShmAttach");
  if (!attach || !segment) return False;
  if (!attach(display, segment)) return False;
  if (!enabled()) return True;
  auto capture = std::make_shared<wemeet::Capture>();
  {
    std::lock_guard<std::mutex> lock(sessions_mutex);
    sessions.emplace(segment->shmseg, Session{capture, display, segment->shmaddr});
  }
  return True;
}

extern "C" Bool XShmGetImage(Display *display, Drawable drawable, XImage *image, int x, int y, unsigned long planes) {
  static const auto get = original<decltype(&XShmGetImage)>("XShmGetImage");
  if (!image) return False;
  std::shared_ptr<wemeet::Capture> capture;
  {
    std::lock_guard<std::mutex> lock(sessions_mutex);
    // Activate only for a shared image read; ordinary Qt uploads never ask for capture.
    for (const auto &entry : sessions) {
      if (entry.second.display == display && entry.second.address == image->data) {
        capture = entry.second.capture;
        break;
      }
    }
  }
  if (capture) return capture->start() && capture->render(*image) ? True : False;
  return get ? get(display, drawable, image, x, y, planes) : False;
}

extern "C" Bool XShmDetach(Display *display, XShmSegmentInfo *segment) {
  static const auto detach = original<decltype(&XShmDetach)>("XShmDetach");
  std::shared_ptr<wemeet::Capture> capture;
  if (segment) {
    std::lock_guard<std::mutex> lock(sessions_mutex);
    auto found = sessions.find(segment->shmseg);
    if (found != sessions.end()) {
      capture = std::move(found->second.capture);
      sessions.erase(found);
    }
  }
  if (capture) capture->stop();
  return detach && segment ? detach(display, segment) : False;
}

extern "C" Bool XDamageQueryExtension(Display *display, int *event, int *error) {
  using Function = Bool (*)(Display *, int *, int *);
  static const auto query = original<Function>("XDamageQueryExtension");
  return enabled() ? False : query ? query(display, event, error) : False;
}
