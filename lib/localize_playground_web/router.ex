defmodule LocalizePlaygroundWeb.Router do
  use LocalizePlaygroundWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LocalizePlaygroundWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", LocalizePlaygroundWeb do
    pipe_through :browser

    live "/", LocalesLive, :locales
    live "/locales", LocalesLive, :locales
    live "/numbers", PageLive, :numbers
  end
end
