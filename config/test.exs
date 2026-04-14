import Config

config :localize_playground, LocalizePlaygroundWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-secret-key-base-test-secret-key-base-test-secret-key-base",
  server: false

config :logger, level: :warning
