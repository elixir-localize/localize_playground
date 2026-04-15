defmodule LocalizePlaygroundWeb.HexDocs do
  @moduledoc """
  Helper for decorating call-code strings with HexDocs links.

  Scans a code fragment for `Module.Submodule.function` identifiers
  that start with `Localize.` and turns each match into an anchor
  that opens a slide-out documentation panel (via a JS hook). Used
  by the Numbers / Dates / Intervals / Durations / Collation tabs.
  """

  use Phoenix.Component

  # The slide-out panel itself — rendered once per page layout.
  attr :id, :string, default: "hexdocs-panel"

  def panel(assigns) do
    ~H"""
    <div id={@id} class="lp-hexdocs-panel" phx-hook="HexDocsPanel" aria-hidden="true">
      <div class="lp-hexdocs-backdrop" data-hexdocs-close></div>
      <aside class="lp-hexdocs-aside" role="dialog" aria-modal="true">
        <header class="lp-hexdocs-header">
          <a class="lp-hexdocs-external" data-hexdocs-external target="_blank" rel="noopener" title="Open in new tab">↗</a>
          <button type="button" class="lp-hexdocs-close" data-hexdocs-close aria-label="Close">✕</button>
        </header>
        <iframe class="lp-hexdocs-iframe" data-hexdocs-frame></iframe>
      </aside>
    </div>
    """
  end

  # Render a call-code fragment with function identifiers linkified.
  attr :code, :string, required: true
  attr :class, :string, default: "lp-call-code-text"
  attr :id, :string, default: nil

  def code(assigns) do
    parts = parse(assigns.code)
    assigns = assign(assigns, :parts, parts)

    ~H"""
    <pre class={@class} id={@id}><%= for part <- @parts do %><.segment part={part} /><% end %></pre>
    """
  end

  attr :part, :any, required: true

  defp segment(%{part: {:text, text}} = assigns) do
    assigns = assign(assigns, :text, text)
    ~H|<%= @text %>|
  end

  defp segment(%{part: {:fun, module_path, func, arity, text}} = assigns) do
    proxied = hexdocs_url(module_path, func, arity)
    external = external_hexdocs_url(module_path, func, arity)

    assigns =
      assigns
      |> assign(:url, proxied)
      |> assign(:external_url, external)
      |> assign(:text, text)

    ~H"""
    <a href={@url} data-hexdocs-external-url={@external_url} class="lp-hexdocs-link" data-hexdocs target="_blank" rel="noopener">{@text}</a>
    """
  end

  @doc """
  Split a call-code string into alternating `{:text, str}` and
  `{:fun, "Localize.Foo", "func", arity_guess, display_text}` tuples.

  Only `Localize.*` module chains are linkified.
  """
  @spec parse(String.t()) :: [{:text, String.t()} | {:fun, String.t(), String.t(), non_neg_integer(), String.t()}]
  def parse(code) when is_binary(code) do
    regex = ~r/Localize(?:\.[A-Z][A-Za-z0-9_]*)+\.[a-z_][A-Za-z0-9_?!]*/

    # Use split with trim:false and include_captures to get alternating
    # text/match segments.
    segments = Regex.split(regex, code, include_captures: true, trim: false)

    Enum.flat_map(segments, fn seg ->
      cond do
        seg == "" ->
          []

        Regex.match?(~r/\ALocalize\./, seg) ->
          # Find the offset where this segment ends in the original code
          # so we can inspect the following paren group for arity.
          case Regex.run(~r/^(Localize(?:\.[A-Z][A-Za-z0-9_]*)+)\.([a-z_][A-Za-z0-9_?!]*)$/, seg,
                 capture: :all_but_first
               ) do
            [path, func] ->
              # Look up the original context to determine arity.
              after_match = extract_tail(code, seg)
              arity = guess_arity(after_match)
              [{:fun, path, func, arity, seg}]

            _ ->
              [{:text, seg}]
          end

        true ->
          [{:text, seg}]
      end
    end)
  end

  # Given the full code and a matched segment (e.g. "Localize.Number.to_string"),
  # return the substring following that match so we can peek at the paren
  # group.
  defp extract_tail(code, match) do
    case :binary.match(code, match) do
      {start, len} -> binary_part(code, start + len, byte_size(code) - start - len)
      _ -> ""
    end
  end

  # Very crude arity guesser: count top-level commas in the parenthesised
  # argument list immediately following the function identifier. Returns 0
  # for `func()` and 1+ otherwise.
  defp guess_arity(tail) do
    case String.trim_leading(tail) do
      "(" <> rest -> count_top_level_args(rest, 0, 1, false)
      _ -> 0
    end
  end

  defp count_top_level_args("", count, _depth, any_content?), do: adjust(count, any_content?)

  defp count_top_level_args(<<?), rest::binary>>, count, 1, any_content?) do
    _ = rest
    adjust(count, any_content?)
  end

  defp count_top_level_args(<<?(, rest::binary>>, count, depth, _any) do
    count_top_level_args(rest, count, depth + 1, true)
  end

  defp count_top_level_args(<<?), rest::binary>>, count, depth, any) do
    count_top_level_args(rest, count, depth - 1, any)
  end

  defp count_top_level_args(<<?,, rest::binary>>, count, 1, _any) do
    count_top_level_args(rest, count + 1, 1, true)
  end

  defp count_top_level_args(<<?", rest::binary>>, count, depth, _any) do
    # Skip to end of string literal to avoid counting commas inside.
    skip_string(rest, count, depth, ?")
  end

  defp count_top_level_args(<<_::utf8, rest::binary>>, count, depth, _any),
    do: count_top_level_args(rest, count, depth, true)

  defp skip_string(<<?\\, _::utf8, rest::binary>>, count, depth, quote),
    do: skip_string(rest, count, depth, quote)

  defp skip_string(<<q, rest::binary>>, count, depth, q),
    do: count_top_level_args(rest, count, depth, true)

  defp skip_string(<<_::utf8, rest::binary>>, count, depth, quote),
    do: skip_string(rest, count, depth, quote)

  defp skip_string("", count, _depth, _quote), do: count

  defp adjust(0, false), do: 0
  defp adjust(count, _any), do: count + 1

  @doc """
  Returns the HexDocs URL for a given `Localize` module path, function
  name, and arity. Falls back to the module page when arity is 0.
  """
  @spec hexdocs_url(String.t(), String.t(), non_neg_integer()) :: String.t()
  def hexdocs_url(module_path, func, arity) do
    # Point at our own proxy so the slide-out iframe can embed the page
    # (HexDocs blocks third-party framing with X-Frame-Options).
    base = "/hexdocs/localize/#{module_path}.html"

    cond do
      arity > 0 -> "#{base}##{func}/#{arity}"
      true -> "#{base}##{func}"
    end
  end

  @doc """
  Returns the direct HexDocs URL (used for the "open in new tab" button
  inside the slide-out panel).
  """
  def external_hexdocs_url(module_path, func, arity) do
    base = "https://hexdocs.pm/localize/#{module_path}.html"

    cond do
      arity > 0 -> "#{base}##{func}/#{arity}"
      true -> "#{base}##{func}"
    end
  end
end
