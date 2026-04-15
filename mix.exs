defmodule LocalizePlayground.MixProject do
  use Mix.Project

  def project do
    [
      app: :localize_playground,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      gettext: [fuzzy_threshold: 0.9],
      deps: deps()
    ]
  end

  def application do
    [
      mod: {LocalizePlayground.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :ssl]
    ]
  end

  defp deps do
    [
      {:localize, path: "../localize", override: true},
      {:localize_web, path: "../localize_web"},
      {:calendrical, path: "../calendrical"},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0"},
      {:bandit, "~> 1.5"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:phoenix_live_reload, "~> 1.5", only: :dev}
    ]
  end
end
