// SPDX-License-Identifier: MIT
#pragma once

#include <gio/gio.h>
#include <gio/gunixfdlist.h>
#include <atomic>
#include <string>

namespace wemeet {

// A private bus connection owns all requests and the session. Request.Close does
// not promise a Response signal; cancellation must never wait for that signal.
class ScreenPortal {
public:
  ScreenPortal() = default;
  ScreenPortal(const ScreenPortal &) = delete;
  ScreenPortal &operator=(const ScreenPortal &) = delete;
  ~ScreenPortal() {
    if (!bus_) return;
    if (!request_.empty()) close_object(request_, "org.freedesktop.portal.Request");
    if (!session_.empty()) close_object(session_, "org.freedesktop.portal.Session");
    if (responses_) g_dbus_connection_signal_unsubscribe(bus_, responses_);
    if (closed_signal_) g_dbus_connection_signal_unsubscribe(bus_, closed_signal_);
    g_dbus_connection_close_sync(bus_, nullptr, nullptr);
    g_object_unref(bus_);
    if (response_) g_variant_unref(response_);
  }

  bool open(std::atomic<bool> &stop, GMainContext *context, std::string &error) {
    GError *failure{};
    gchar *address = g_dbus_address_get_for_bus_sync(G_BUS_TYPE_SESSION, nullptr, &failure);
    if (!address) { take_error(failure, error); return false; }
    bus_ = g_dbus_connection_new_for_address_sync(address,
      GDBusConnectionFlags(G_DBUS_CONNECTION_FLAGS_AUTHENTICATION_CLIENT | G_DBUS_CONNECTION_FLAGS_MESSAGE_BUS_CONNECTION), nullptr, nullptr, &failure);
    g_free(address);
    if (!bus_) { take_error(failure, error); return false; }
    g_dbus_connection_set_exit_on_close(bus_, false);
    responses_ = g_dbus_connection_signal_subscribe(bus_, service, "org.freedesktop.portal.Request", "Response", nullptr, nullptr,
      G_DBUS_SIGNAL_FLAGS_NONE,
      [](GDBusConnection *, const char *, const char *path, const char *, const char *, GVariant *parameters, gpointer data) {
        auto &self = *static_cast<ScreenPortal *>(data);
        if (self.request_ != path) return;
        if (self.response_) g_variant_unref(self.response_);
        self.response_ = g_variant_ref(parameters);
      }, this, nullptr);

    GVariantBuilder options;
    g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
    const std::string session_token = token();
    std::string sender = g_dbus_connection_get_unique_name(bus_);
    sender.erase(0, 1);
    for (auto &character : sender) if (character == '.') character = '_';
    // Keep ownership before CreateSession returns, including cancellation races.
    session_ = "/org/freedesktop/portal/desktop/session/" + sender + '/' + session_token;
    g_variant_builder_add(&options, "{sv}", "handle_token", g_variant_new_string(token().c_str()));
    g_variant_builder_add(&options, "{sv}", "session_handle_token", g_variant_new_string(session_token.c_str()));
    GVariant *created = request("CreateSession", g_variant_new("(a{sv})", &options), stop, context, error);
    if (!created) return false;
    const char *session{};
    // ScreenCast's historical session_handle result is a string, not an 'o'.
    if (!g_variant_lookup(created, "session_handle", "&s", &session) || !g_variant_is_object_path(session)) {
      g_variant_unref(created); error = "portal returned an invalid session_handle"; return false;
    }
    session_ = session;
    g_variant_unref(created);
    closed_signal_ = g_dbus_connection_signal_subscribe(bus_, service, "org.freedesktop.portal.Session", "Closed", session_.c_str(), nullptr,
      G_DBUS_SIGNAL_FLAGS_NONE,
      [](GDBusConnection *, const char *, const char *, const char *, const char *, GVariant *, gpointer data) {
        static_cast<ScreenPortal *>(data)->closed_ = true;
      }, this, nullptr);

    g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
    g_variant_builder_add(&options, "{sv}", "handle_token", g_variant_new_string(token().c_str()));
    g_variant_builder_add(&options, "{sv}", "types", g_variant_new_uint32(3));
    g_variant_builder_add(&options, "{sv}", "multiple", g_variant_new_boolean(false));
    g_variant_builder_add(&options, "{sv}", "cursor_mode", g_variant_new_uint32(2));
    g_variant_builder_add(&options, "{sv}", "persist_mode", g_variant_new_uint32(0));
    GVariant *selected = request("SelectSources", g_variant_new("(oa{sv})", session_.c_str(), &options), stop, context, error);
    if (!selected) return false;
    g_variant_unref(selected);

    g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
    g_variant_builder_add(&options, "{sv}", "handle_token", g_variant_new_string(token().c_str()));
    GVariant *started = request("Start", g_variant_new("(osa{sv})", session_.c_str(), "", &options), stop, context, error);
    if (!started) return false;
    GVariant *streams = g_variant_lookup_value(started, "streams", G_VARIANT_TYPE("a(ua{sv})"));
    g_variant_unref(started);
    if (!streams || g_variant_n_children(streams) != 1) {
      if (streams) g_variant_unref(streams);
      error = "portal did not return exactly one selected stream"; return false;
    }
    GVariant *stream = g_variant_get_child_value(streams, 0);
    g_variant_get_child(stream, 0, "u", &node_);
    g_variant_unref(stream);
    g_variant_unref(streams);
    return true;
  }

  int open_remote(std::string &error) {
    GError *failure{};
    GUnixFDList *descriptors{};
    GVariant *reply = g_dbus_connection_call_with_unix_fd_list_sync(bus_, service, desktop, "org.freedesktop.portal.ScreenCast", "OpenPipeWireRemote",
      g_variant_new("(oa{sv})", session_.c_str(), nullptr), G_VARIANT_TYPE("(h)"), G_DBUS_CALL_FLAGS_NONE, 10000,
      nullptr, &descriptors, nullptr, &failure);
    if (!reply) { take_error(failure, error); return -1; }
    gint index{};
    g_variant_get(reply, "(h)", &index);
    int fd = descriptors ? g_unix_fd_list_get(descriptors, index, &failure) : -1;
    g_variant_unref(reply);
    if (descriptors) g_object_unref(descriptors);
    if (fd < 0) { take_error(failure, error); if (error.empty()) error = "portal omitted PipeWire descriptor"; }
    return fd;
  }

  uint32_t node() const { return node_; }
  bool closed() const { return closed_; }

private:
  static constexpr const char *service = "org.freedesktop.portal.Desktop";
  static constexpr const char *desktop = "/org/freedesktop/portal/desktop";
  static std::string token() { return "wemeet" + std::to_string(g_random_int()); }
  static void take_error(GError *failure, std::string &error) {
    error = failure ? failure->message : "portal communication failed";
    g_clear_error(&failure);
  }

  void close_object(const std::string &path, const char *interface) {
    GVariant *reply = g_dbus_connection_call_sync(bus_, service, path.c_str(), interface, "Close", nullptr, G_VARIANT_TYPE("()"),
      G_DBUS_CALL_FLAGS_NONE, 3000, nullptr, nullptr);
    if (reply) g_variant_unref(reply);
  }

  GVariant *request(const char *method, GVariant *parameters, std::atomic<bool> &stop, GMainContext *context, std::string &error) {
    GError *failure{};
    GVariant *reply = g_dbus_connection_call_sync(bus_, service, desktop, "org.freedesktop.portal.ScreenCast", method, parameters,
      G_VARIANT_TYPE("(o)"), G_DBUS_CALL_FLAGS_NONE, 10000, nullptr, &failure);
    if (!reply) { take_error(failure, error); return nullptr; }
    const char *handle{};
    g_variant_get(reply, "(&o)", &handle);
    request_ = handle;
    g_variant_unref(reply);
    while (!response_ && !stop.load() && !closed_) {
      while (g_main_context_iteration(context, false)) {}
      if (!response_) g_usleep(10000);
    }
    if (!response_) {
      error = stop.load() ? "screen selection cancelled" : "portal session closed";
      return nullptr;
    }
    guint status{};
    GVariant *results{};
    g_variant_get(response_, "(u@a{sv})", &status, &results);
    g_variant_unref(response_);
    response_ = nullptr;
    request_.clear();
    if (status == 0 && !stop.load()) return results;
    g_variant_unref(results);
    error = status == 1 || stop.load() ? "screen selection cancelled" : "portal screen selection failed";
    return nullptr;
  }

  GDBusConnection *bus_{};
  guint responses_{}, closed_signal_{};
  GVariant *response_{};
  std::string session_, request_;
  uint32_t node_{};
  bool closed_{};
};

} // namespace wemeet
