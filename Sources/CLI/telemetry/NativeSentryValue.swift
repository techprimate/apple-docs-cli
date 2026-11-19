#if os(Linux)
    import SentryNative

    enum NativeSentryValue {
        static func object(_ values: [String: Any]) -> sentry_value_t {
            let object = sentry_value_new_object()
            for (key, value) in values {
                sentry_value_set_by_key(object, key, scalar(value))
            }
            return object
        }

        static func attributes(_ values: [String: String]) -> sentry_value_t {
            let object = sentry_value_new_object()
            for (key, value) in values {
                sentry_value_set_by_key(
                    object, key, sentry_value_new_attribute(sentry_value_new_string(value), nil)
                )
            }
            return object
        }

        static func scalar(_ value: Any) -> sentry_value_t {
            if let value = value as? Bool {
                return sentry_value_new_bool(value ? 1 : 0)
            }
            return sentry_value_new_string(String(describing: value))
        }
    }
#endif
