import Config

# Endpoint settings compiled into the release. Runtime-configurable
# values (PORT, SECRET_KEY_BASE, host, etc.) live in runtime.exs so
# they can be overridden with env vars without recompiling.
config :localize_playground, LocalizePlaygroundWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production.
config :logger, level: :info
