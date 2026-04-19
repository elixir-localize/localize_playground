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

  # MF2_EDITOR_INTEGRATION: dependency declaration
  #
  # `mf2_wasm_editor` is the browser-side MF2 highlighter + LiveView
  # hook. It's a standard hex dep. The toggle below lets us iterate
  # against a sibling checkout (`LOCALIZE_PATH_DEPS=1`) during
  # development; hex mode is what Docker and fly.io use.
  #
  # This is one of six integration points in the playground — grep
  # for MF2_EDITOR_INTEGRATION to find them all. See README § "MF2
  # editor integration" for the full map.
  #
  # Guide: https://hexdocs.pm/mf2_wasm_editor/mf2_wasm_editor.html
  #
  # Ecosystem packages can be pulled from hex (for fly.io deploy) or
  # from sibling paths (for local dev iteration). Toggle via the
  # LOCALIZE_PATH_DEPS env var — when set to a truthy value, mix uses
  # path deps; otherwise hex deps. Docker builds ignore the env var
  # and always use hex.
  @path_deps System.get_env("LOCALIZE_PATH_DEPS") in ~w(1 true yes)

  defp ecosystem_deps do
    if @path_deps do
      [
        {:localize, path: "../localize", override: true},
        {:mf2_wasm_editor, path: "../mf2_wasm_editor"}
      ]
    else
      [
        {:localize, "~> 0.18"},
        {:mf2_wasm_editor, "~> 0.1"}
      ]
    end
  end

  defp deps do
    [
      {:localize_web, "~> 0.4"}
    ] ++ ecosystem_deps() ++ [
      {:calendrical, "~> 0.2"},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.0"},
      {:tz, "~> 0.28"},
      {:bandit, "~> 1.5"},
      {:gettext, "~> 1.0"},
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 1.0"},
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
