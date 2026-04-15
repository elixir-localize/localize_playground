defmodule LocalizePlaygroundWeb.UiLocaleController do
  @moduledoc """
  Endpoint for changing the UI locale. The picker posts here, we save
  the choice in the session, and redirect back to wherever the user
  came from.
  """

  use Phoenix.Controller, formats: [:html]
  import Plug.Conn

  alias LocalizePlaygroundWeb.UiLocale

  def update(conn, params) do
    locale = params["locale"]
    # Use the Referer header (set automatically by the browser on
    # form submit) so the user stays on whatever tab they were
    # viewing. Hidden return_to field is a secondary hint and is
    # only used when Referer is missing.
    return_to =
      safe_return(referer_path(conn)) ||
        safe_return(params["return_to"]) ||
        "/"

    conn =
      if is_binary(locale) and UiLocale.known?(locale) do
        put_session(conn, UiLocale.session_key(), locale)
      else
        conn
      end

    redirect(conn, to: return_to)
  end

  defp referer_path(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] ->
        case URI.parse(referer) do
          %URI{path: path, query: query} when is_binary(path) ->
            if is_binary(query) and query != "", do: "#{path}?#{query}", else: path

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  # Only allow internal paths to prevent open-redirect abuse. Returns
  # `nil` for invalid/missing input so the caller can fall back to
  # the next source.
  defp safe_return(nil), do: nil
  defp safe_return(""), do: nil

  defp safe_return("/" <> _ = path) do
    if String.contains?(path, "//") or String.contains?(path, ":"), do: nil, else: path
  end

  defp safe_return(_), do: nil
end
