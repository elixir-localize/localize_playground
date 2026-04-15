defmodule LocalizePlaygroundWeb.Router do
  use LocalizePlaygroundWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LocalizePlaygroundWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug Localize.Plug.PutLocale,
      from: [:query, :session, :accept_language],
      param: "ui_locale",
      default: Localize.default_locale(),
      gettext: LocalizePlaygroundWeb.Gettext

    plug Localize.Plug.PutSession, as: :string
  end

  scope "/", LocalizePlaygroundWeb do
    pipe_through :browser

    post "/ui-locale", UiLocaleController, :update

    get "/hexdocs/*path", HexDocsProxy, :show

    live "/", LocalesLive, :locales
    live "/locales", LocalesLive, :locales
    live "/numbers", PageLive, :numbers
    live "/dates", DatesLive, :dates
    live "/intervals", IntervalsLive, :intervals
    live "/durations", DurationsLive, :durations
    live "/units", UnitsLive, :units
    live "/messages", MessagesLive, :messages
    live "/collation", CollationLive, :collation
  end
end
