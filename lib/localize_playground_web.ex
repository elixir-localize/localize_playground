defmodule LocalizePlaygroundWeb do
  @moduledoc false

  def static_paths,
    do: ~w(assets favicon.ico favicon-16.png favicon-32.png apple-touch-icon.png robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {LocalizePlaygroundWeb.Layouts, :app}
      on_mount({LocalizePlaygroundWeb.UiLocaleHook, :default})

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import LocalizePlaygroundWeb.CoreComponents
      use Gettext, backend: LocalizePlaygroundWeb.Gettext
      alias Phoenix.LiveView.JS
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
