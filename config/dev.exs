import Config

config :localize_playground, LocalizePlaygroundWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "LWPXQqKnGx4Rq0c7Y0G2kz1p0pYvQ3p4eCvKs8b6m3jLq6rUy8cQv9xE3bJ1pKfA",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/localize_playground_web/(components|live|controllers)/.*(ex|heex)$"
    ]
  ]

config :logger, :console,
  format: "[$level] $message\n",
  level: :info

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :localize, :allow_runtime_locale_download, true
