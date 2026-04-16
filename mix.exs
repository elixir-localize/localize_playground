defmodule LocalizePlayground.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :localize_playground,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      gettext: [fuzzy_threshold: 0.9],
      aliases: aliases(),
      releases: releases(),
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
      {:localize, "~> 0.14"},
      {:localize_web, "~> 0.4"},
      {:calendrical, "~> 0.2"},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0"},
      {:tz, "~> 0.28"},
      {:bandit, "~> 1.5"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:phoenix_live_reload, "~> 1.5", only: :dev}
    ]
  end

  # Mix aliases bundle build/setup tasks so they can be invoked with
  # a single command (useful in CI and release scripts).
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild default"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end

  # Release definition for `mix release`. Produces a self-contained
  # tarball under `_build/prod/rel/localize_playground/` that bundles
  # the Erlang runtime and every dependency — suitable for deploying
  # to a server without Elixir installed.
  defp releases do
    [
      localize_playground: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, :tar],
        strip_beams: Mix.env() == :prod
      ]
    ]
  end
end
