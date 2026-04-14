defmodule LocalizePlayground.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: LocalizePlayground.PubSub},
      LocalizePlaygroundWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: LocalizePlayground.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    LocalizePlaygroundWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
