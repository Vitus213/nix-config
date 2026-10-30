// SPDX-License-Identifier: MIT
#include <QWidget>
#include <QMetaObject>
#include <dlfcn.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

// The shipped Linux tracker is made of opaque green ShadeLine widgets. With
// xwayland-satellite they become separate full-size surfaces instead of borders.
// Keep all other QWidget visibility behavior, including the sharing toolbar.
extern "C" void _ZN7QWidget10setVisibleEb(QWidget *widget, bool visible) {
  using SetVisible = void (*)(QWidget *, bool);
  static const auto original = reinterpret_cast<SetVisible>(dlsym(RTLD_NEXT, "_ZN7QWidget10setVisibleEb"));
  if (!original) return;
  const char *capture = std::getenv("WEMEET_WAYLAND_CAPTURE");
  if (visible && capture && std::strcmp(capture, "1") == 0) {
    using ClassName = const char *(*)(const QMetaObject *);
    static const auto class_name = reinterpret_cast<ClassName>(dlsym(RTLD_NEXT, "_ZNK11QMetaObject9classNameEv"));
    const char *name = class_name ? class_name(widget->metaObject()) : nullptr;
    if (name && (std::strcmp(name, "linux_qt::ShadeLine") == 0 || std::strcmp(name, "linux_qt::TrackerWidget") == 0)) {
      std::fprintf(stderr, "[wemeet capture] suppressing X11 border overlay %s\n", name);
      original(widget, false);
      return;
    }
  }
  original(widget, visible);
}
