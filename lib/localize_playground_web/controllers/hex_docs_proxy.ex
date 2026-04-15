defmodule LocalizePlaygroundWeb.HexDocsProxy do
  @moduledoc """
  Thin server-side proxy for `hexdocs.pm/localize/*` pages.

  HexDocs sends `X-Frame-Options: SAMEORIGIN`, which stops us from
  embedding docs in the slide-out panel on the playground tabs. This
  proxy fetches the upstream response, drops the frame-blocking
  headers, rewrites internal anchors and stylesheet/script URLs to
  stay inside the proxy (so relative links still work), and returns
  the body.

  Scope is strictly limited to the `localize` package on HexDocs —
  unrelated paths return a 404 — so we're not turning the playground
  into an open proxy.
  """

  use Phoenix.Controller, formats: [:html]
  import Plug.Conn

  @base "https://hexdocs.pm"

  def show(conn, %{"path" => path_parts} = params) do
    path = "/" <> Enum.join(path_parts, "/")

    unless String.starts_with?(path, "/localize/") do
      conn |> send_resp(404, "Not found") |> halt()
    else
      url = @base <> path <> query_suffix(params)
      fetch_and_forward(conn, url)
    end
  end

  defp query_suffix(params) do
    params
    |> Map.drop(["path"])
    |> URI.encode_query()
    |> case do
      "" -> ""
      q -> "?" <> q
    end
  end

  defp fetch_and_forward(conn, url) do
    case :httpc.request(:get, {String.to_charlist(url), [{~c"user-agent", ~c"localize-playground-proxy"}]}, [], body_format: :binary) do
      {:ok, {{_, status, _}, headers, body}} when status in 200..299 ->
        content_type = find_header(headers, ~c"content-type") || "text/html; charset=utf-8"
        body = maybe_rewrite(body, content_type)

        conn
        |> put_resp_content_type(content_type)
        # Strip any X-Frame-Options that would prevent embedding
        |> delete_resp_header("x-frame-options")
        |> delete_resp_header("content-security-policy")
        |> send_resp(200, body)

      {:ok, {{_, status, _}, _headers, body}} ->
        send_resp(conn, status, body)

      {:error, reason} ->
        send_resp(conn, 502, "Upstream error: #{inspect(reason)}")
    end
  end

  defp find_header(headers, name) do
    Enum.find_value(headers, fn {k, v} -> if :string.to_lower(k) == name, do: to_string(v) end)
  end

  # Only rewrite HTML — static assets pass through untouched.
  defp maybe_rewrite(body, content_type) do
    if String.contains?(content_type, "text/html") do
      rewrite_html(body)
    else
      body
    end
  end

  # Point relative absolute-path URLs (`/localize/...`, `/stylesheets/...`,
  # `/dist/...` etc.) at our proxy. Absolute `https://hexdocs.pm/...`
  # URLs in attributes get the same treatment. Anchors unchanged.
  defp rewrite_html(body) do
    body
    |> String.replace(~r{(href|src)="https://hexdocs\.pm}, ~S|\1="/hexdocs|)
    |> String.replace(~r{(href|src)="/(?!hexdocs)([^"]*)"}, ~S|\1="/hexdocs/\2"|)
  end
end
