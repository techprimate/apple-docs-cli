#include "NativeTelemetryPrivacy.h"
#include <string.h>

static const char *command_keys[] = {"apple_docs.technology", "apple_docs.type",
                                     "cli.command", "cli.output_json"};
static const char *context_keys[] = {"cli", "os", "runtime", "trace"};
static const char *log_bodies[] = {"CLI command completed",
                                   "CLI command failed", "CLI command rejected",
                                   "CLI command started"};
static const char *log_attributes[] = {"environment",
                                       "release",
                                       "sentry.origin",
                                       "sentry.sdk.name",
                                       "sentry.sdk.version",
                                       "swift-log.apple_docs.technology",
                                       "swift-log.apple_docs.type",
                                       "swift-log.cli.command",
                                       "swift-log.cli.output_json",
                                       "swift-log.level"};
static const char *metric_names[] = {
    "apple_docs.response.size",        "apple_docs.technology.catalog.count",
    "apple_docs.type.catalog.count",   "apple_docs.type.search.result.count",
    "apple_docs.technology.requested", "apple_docs.type.requested"};
static const char *metric_attributes[] = {"apple_docs.technology",
                                          "apple_docs.type", "cli.command",
                                          "environment", "release"};

#define COUNT(array) (sizeof(array) / sizeof((array)[0]))

static int contains(const char *value, const char *const *allowed,
                    size_t count) {
  for (size_t i = 0; i < count; i++) {
    if (strcmp(value, allowed[i]) == 0) {
      return 1;
    }
  }
  return 0;
}

struct key_filter {
  sentry_value_t object;
  const char *const *allowed;
  size_t count;
};

static int filter_key(const char *key, sentry_value_t value, void *userdata) {
  (void)value;
  struct key_filter *filter = userdata;
  if (!contains(key, filter->allowed, filter->count)) {
    sentry_value_remove_by_key(filter->object, key);
  }
  return 0;
}

static void filter_keys(sentry_value_t object, const char *const *allowed,
                        size_t count) {
  struct key_filter filter = {object, allowed, count};
  sentry_value_foreach_key_value(object, filter_key, &filter);
}

static void sanitize_path(sentry_value_t object, const char *key) {
  sentry_value_t value = sentry_value_get_by_key(object, key);
  if (sentry_value_get_type(value) != SENTRY_VALUE_TYPE_STRING) {
    return;
  }
  const char *path = sentry_value_as_string(value);
  const char *name = strrchr(path, '/');
  if (name) {
    sentry_value_set_by_key(object, key, sentry_value_new_string(name + 1));
  }
}

static void sanitize_stack(sentry_value_t entry) {
  sentry_value_t frames = sentry_value_get_by_key(
      sentry_value_get_by_key(entry, "stacktrace"), "frames");
  for (size_t i = 0; i < sentry_value_get_length(frames); i++) {
    sentry_value_t frame = sentry_value_get_by_index(frames, i);
    sanitize_path(frame, "package");
    sanitize_path(frame, "filename");
    sanitize_path(frame, "abs_path");
  }
}

/* Crash filtering stays in C so a corrupted Swift runtime is not re-entered. */
static sentry_value_t filter_event(sentry_value_t event, sentry_hint_t *hint,
                                   void *userdata) {
  (void)hint;
  (void)userdata;
  const char *removed[] = {"user", "request", "server_name", "extra",
                           "tags", "message", "error"};
  for (size_t i = 0; i < COUNT(removed); i++) {
    sentry_value_remove_by_key(event, removed[i]);
  }
  sentry_value_t contexts = sentry_value_get_by_key(event, "contexts");
  filter_keys(contexts, context_keys, COUNT(context_keys));
  filter_keys(sentry_value_get_by_key(contexts, "cli"), command_keys,
              COUNT(command_keys));
  filter_keys(sentry_value_get_by_key(
                  sentry_value_get_by_key(contexts, "trace"), "data"),
              command_keys, COUNT(command_keys));

  sentry_value_t breadcrumbs = sentry_value_get_by_key(event, "breadcrumbs");
  if (!sentry_value_is_null(breadcrumbs)) {
    sentry_value_t filtered = sentry_value_new_list();
    for (size_t i = 0; i < sentry_value_get_length(breadcrumbs); i++) {
      sentry_value_t breadcrumb = sentry_value_get_by_index(breadcrumbs, i);
      const char *category = sentry_value_as_string(
          sentry_value_get_by_key(breadcrumb, "category"));
      if (strcmp(category, "cli.command") != 0) {
        continue;
      }
      sentry_value_set_by_key(breadcrumb, "message",
                              sentry_value_new_string("CLI command invoked"));
      sentry_value_set_by_key(breadcrumb, "type",
                              sentry_value_new_string("user"));
      filter_keys(sentry_value_get_by_key(breadcrumb, "data"), command_keys,
                  COUNT(command_keys));
      sentry_value_incref(breadcrumb);
      sentry_value_append(filtered, breadcrumb);
    }
    sentry_value_set_by_key(event, "breadcrumbs", filtered);
  }

  sentry_value_t images = sentry_value_get_by_key(
      sentry_value_get_by_key(event, "debug_meta"), "images");
  for (size_t i = 0; i < sentry_value_get_length(images); i++) {
    sentry_value_t image = sentry_value_get_by_index(images, i);
    sanitize_path(image, "code_file");
    sanitize_path(image, "debug_file");
  }
  sentry_value_t exceptions = sentry_value_get_by_key(
      sentry_value_get_by_key(event, "exception"), "values");
  for (size_t i = 0; i < sentry_value_get_length(exceptions); i++) {
    sentry_value_t exception = sentry_value_get_by_index(exceptions, i);
    sentry_value_set_by_key(exception, "value",
                            sentry_value_new_string("CLI command failed"));
    sanitize_stack(exception);
  }
  sentry_value_t threads = sentry_value_get_by_key(
      sentry_value_get_by_key(event, "threads"), "values");
  for (size_t i = 0; i < sentry_value_get_length(threads); i++) {
    sanitize_stack(sentry_value_get_by_index(threads, i));
  }
  return event;
}

static sentry_value_t filter_transaction(sentry_value_t transaction,
                                         void *userdata) {
  sentry_value_t trace = sentry_value_get_by_key(
      sentry_value_get_by_key(transaction, "contexts"), "trace");
  if (strcmp(sentry_value_as_string(sentry_value_get_by_key(trace, "op")),
             "console.command") != 0) {
    sentry_value_decref(transaction);
    return sentry_value_new_null();
  }
  sentry_value_set_by_key(transaction, "spans", sentry_value_new_list());
  return filter_event(transaction, NULL, userdata);
}

static sentry_value_t filter_log(sentry_value_t log, void *userdata) {
  (void)userdata;
  const char *body =
      sentry_value_as_string(sentry_value_get_by_key(log, "body"));
  if (!contains(body, log_bodies, COUNT(log_bodies))) {
    sentry_value_decref(log);
    return sentry_value_new_null();
  }
  filter_keys(sentry_value_get_by_key(log, "attributes"), log_attributes,
              COUNT(log_attributes));
  return log;
}

static sentry_value_t filter_metric(sentry_value_t metric, void *userdata) {
  (void)userdata;
  const char *name =
      sentry_value_as_string(sentry_value_get_by_key(metric, "name"));
  if (!contains(name, metric_names, COUNT(metric_names))) {
    sentry_value_decref(metric);
    return sentry_value_new_null();
  }
  filter_keys(sentry_value_get_by_key(metric, "attributes"), metric_attributes,
              COUNT(metric_attributes));
  return metric;
}

void apple_docs_configure_privacy(sentry_options_t *options) {
  sentry_options_set_logger(options, NULL, NULL);
  sentry_options_set_before_send(options, filter_event, NULL);
  sentry_options_set_before_transaction(options, filter_transaction, NULL);
  sentry_options_set_before_send_log(options, filter_log, NULL);
  sentry_options_set_before_send_metric(options, filter_metric, NULL);
}
