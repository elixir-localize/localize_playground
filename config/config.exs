import Config

config :localize_playground, LocalizePlaygroundWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LocalizePlaygroundWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: LocalizePlayground.PubSub,
  live_view: [signing_salt: "Uh4qO3Rn+0Xy9m2Zk8sI"]

config :phoenix, :json_library, Jason

config :gettext, :plural_forms, LocalizePlaygroundWeb.GettextPlural

config :esbuild,
  version: "0.23.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2020 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

import_config "#{config_env()}.exs"
