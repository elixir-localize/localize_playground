defmodule LocalizePlaygroundWeb.Mf2Highlighter do
  @moduledoc """
  Tree-sitter backed MF2 highlighter for the Messages tab.

  Replaces the previous `Localize.Message.to_html/2` call. Two wins
  over that route:

    1. **Error-resilient.** The NimbleParsec parser behind `to_html`
       aborts on the first error, so as soon as the user types half
       of a placeholder the whole message falls back to unhighlighted
       HTML. Tree-sitter keeps highlighting the valid parts and
       surfaces the broken regions as diagnostics.

    2. **Consistent with the editor extensions.** The capture names
       emitted here are the same ones used by the Zed / Helix /
       Neovim grammars in `mf2_editor_extensions/tree-sitter-mf2/
       queries/highlights.scm`, so a single stylesheet can cover
       editor highlighting and playground output.

  The module is deliberately small: parse → run the `:highlights`
  query → fold captures into a span-wrapped HTML string → walk the
  tree for `{:error, _}` / `{:missing, _}` diagnostics.
  """

  alias Localize.Mf2.TreeSitter
  alias Localize.Mf2.TreeSitter.{Node, Query}

  @type diagnostic :: %{
          kind: :error | :missing,
          start_byte: non_neg_integer(),
          end_byte: non_neg_integer(),
          start_point: {non_neg_integer(), non_neg_integer()},
          end_point: {non_neg_integer(), non_neg_integer()},
          message: String.t()
        }

  # Compile the highlight query once at module load. It's language-
  # specific and immutable, so caching in a persistent term avoids
  # re-parsing the .scm source on every highlight call.
  @highlight_key {__MODULE__, :highlight_query}

  def init do
    {:ok, query} = Query.load(:highlights)
    :persistent_term.put(@highlight_key, query)
    :ok
  end

  @doc """
  Highlight an MF2 message.

  Returns `{html, diagnostics}` where `html` is a safe HTML string
  (already escaped, ready for `Phoenix.HTML.raw/1`) and `diagnostics`
  is a list of `t:diagnostic/0` maps in source order.
  """
  @spec highlight(String.t()) :: {String.t(), [diagnostic()]}
  def highlight(source) when is_binary(source) do
    case TreeSitter.parse(source) do
      {:ok, tree} ->
        query = highlight_query()
        root = TreeSitter.root(tree)
        captures = Query.captures(query, root)
        html = build_html(source, captures)
        diagnostics = build_diagnostics(tree, source)
        {html, diagnostics}

      {:error, _} ->
        {html_escape(source), []}
    end
  end

  # The assigned capture becomes the CSS class — prefixed with `mf2-`
  # and with `.` → `-` so nested names like `keyword.conditional`
  # survive into CSS selectors.
  defp class_for(capture_name), do: "mf2-" <> String.replace(capture_name, ".", "-")

  defp highlight_query do
    case :persistent_term.get(@highlight_key, :missing) do
      :missing ->
        {:ok, query} = Query.load(:highlights)
        :persistent_term.put(@highlight_key, query)
        query

      query ->
        query
    end
  end

  # Convert the flat capture list into non-overlapping byte ranges
  # with the highest-priority capture at each byte, then fold those
  # plus the un-captured bytes into an HTML string.
  #
  # Tree-sitter captures can overlap when one pattern's match sits
  # inside another (e.g. an identifier inside a function call).
  # We resolve conflicts by taking the *innermost* capture — the one
  # with the smallest byte span — so `@function` on the identifier
  # trumps a broader `@punctuation` wrapping the whole expression.
  defp build_html(source, captures) do
    ranges = resolve_ranges(captures, byte_size(source))
    render(source, ranges, 0, [])
  end

  defp resolve_ranges(captures, source_size) do
    # Build a map from byte offset → capture name, picking the
    # smallest-span capture that covers that byte.
    spans =
      captures
      |> Enum.map(fn {name, node} ->
        %{
          name: name,
          start_byte: Node.start_byte(node),
          end_byte: Node.end_byte(node),
          width: Node.end_byte(node) - Node.start_byte(node)
        }
      end)
      |> Enum.sort_by(& &1.width, :desc)

    # Paint byte-by-byte: later (narrower) spans overwrite earlier
    # (wider) ones. O(n * source_size) — fine for playground inputs.
    paint =
      Enum.reduce(spans, %{}, fn %{name: name, start_byte: s, end_byte: e}, acc ->
        Enum.reduce(s..(e - 1)//1, acc, fn i, a -> Map.put(a, i, name) end)
      end)

    # Collapse consecutive equal labels into `{start, end, label}` runs.
    collapse(paint, source_size)
  end

  defp collapse(paint, source_size) do
    Enum.reduce(0..(source_size - 1)//1, {[], nil, nil}, fn i, {acc, run_start, run_label} ->
      label = Map.get(paint, i)

      cond do
        run_start == nil ->
          {acc, i, label}

        label == run_label ->
          {acc, run_start, run_label}

        true ->
          {[{run_start, i, run_label} | acc], i, label}
      end
    end)
    |> case do
      {acc, nil, _} -> Enum.reverse(acc)
      {acc, start, label} -> Enum.reverse([{start, source_size, label} | acc])
    end
  end

  defp render(source, [], cursor, iodata) do
    tail = binary_part(source, cursor, byte_size(source) - cursor)
    IO.iodata_to_binary(Enum.reverse([html_escape(tail) | iodata]))
  end

  defp render(source, [{start_byte, end_byte, label} | rest], cursor, iodata) do
    iodata =
      if start_byte > cursor do
        gap = binary_part(source, cursor, start_byte - cursor)
        [html_escape(gap) | iodata]
      else
        iodata
      end

    slice = binary_part(source, start_byte, end_byte - start_byte)

    iodata =
      if label do
        [
          "</span>",
          html_escape(slice),
          ~s(<span class=") <> class_for(label) <> ~s(">) | iodata
        ]
      else
        [html_escape(slice) | iodata]
      end

    render(source, rest, end_byte, iodata)
  end

  defp html_escape(binary) do
    binary
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp build_diagnostics(tree, _source) do
    tree
    |> TreeSitter.diagnostics()
    |> Enum.map(fn {kind, node} ->
      %{
        kind: kind,
        start_byte: Node.start_byte(node),
        end_byte: Node.end_byte(node),
        start_point: Node.start_point(node),
        end_point: Node.end_point(node),
        message: diagnostic_message(kind, node)
      }
    end)
  end

  defp diagnostic_message(:missing, node),
    do: "Expected #{inspect(Node.type(node))} here"

  defp diagnostic_message(:error, node) do
    # ERROR nodes in tree-sitter don't carry a message — the presence
    # of the node at a range is the signal. Give a minimal hint based
    # on the parent's type so the playground can show something more
    # useful than "syntax error".
    context =
      case Node.parent(node) do
        %Node{} = p -> "in #{Node.type(p)}"
        nil -> ""
      end

    String.trim("Unexpected input " <> context)
  end
end
