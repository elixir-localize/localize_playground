defmodule LocalizePlaygroundWeb.BindingsParser do
  @moduledoc """
  Safely parses the text a user types into the "Bindings" textarea
  on the Messages tab.

  The playground is exposed over the public internet, so the input
  must be treated as hostile. Historically the tab called
  `Code.eval_string/3` with `__ENV__`, which gives arbitrary code
  execution to any visitor. This module replaces that with a
  literal-only interpreter:

    1. Parse the input to an AST via `Code.string_to_quoted/1`.
    2. Walk the AST and require every node to be a literal: atom,
       number, string, boolean, nil, list, tuple, map, or keyword
       pair. Unary `-` is allowed for negative-number literals.
       Function calls, variables, module references, operators,
       sigils, pipes — none of these pass the check.
    3. Only then evaluate with `Code.eval_quoted/3`. At that point
       the AST is pure data; evaluation is structure reconstruction,
       no side effects.

  ### Accepted shapes

      %{count: 3}
      %{name: "Ada", active: true, tags: ["a", "b"]}
      [count: 3, nested: %{value: -42}]

  ### Date / DateTime / NaiveDateTime sigils

  MF2 formatters take dates, times, and datetimes as operand values,
  so `~D`, `~U`, and `~N` are allowed as a carve-out from the
  literals-only rule. Their body must be a plain string (no
  interpolation) and they take no modifiers:

      %{due: ~D[2026-12-31]}
      %{at: ~U[2026-12-31T23:59:59Z]}
      %{seen: ~N[2026-12-31 23:59:59]}

  Every other sigil (`~r`, `~s` with interpolation, `~w`, user
  sigils) is rejected — each is a function call under the hood
  and runs arbitrary code at build time.

  ### Rejected shapes

      %{x: File.read!("/etc/passwd")}     # function call
      %{x: some_var}                       # variable reference
      %{x: 1 + 2}                          # operator
      %{x: MyMod.constant}                 # module reference
      %{pattern: ~r/[a-z]+/}               # regex sigil (compiles + runs)
      %{items: ~w(a b c)}                  # word-list sigil
      %{x: ~s"hi \#{secret}"}              # interpolating string sigil
  """

  @doc """
  Parses the bindings textarea's text into a map or keyword list.

  ### Returns

  * `{:ok, value}` — parsed value, guaranteed to be a map or keyword list.

  * `{:error, message}` — human-readable message suitable for
    surfacing to the user.

  ### Examples

      iex> LocalizePlaygroundWeb.BindingsParser.parse("")
      {:ok, %{}}

      iex> LocalizePlaygroundWeb.BindingsParser.parse("%{count: 3}")
      {:ok, %{count: 3}}

      iex> LocalizePlaygroundWeb.BindingsParser.parse("[count: 3]")
      {:ok, [count: 3]}

  """
  @spec parse(String.t()) :: {:ok, map() | keyword()} | {:error, String.t()}
  def parse(text) when is_binary(text) do
    trimmed = String.trim(text)

    cond do
      trimmed == "" ->
        {:ok, %{}}

      true ->
        with {:ok, ast} <- Code.string_to_quoted(trimmed),
             :ok <- check_literal(ast),
             {value, _} <- safe_eval(ast),
             :ok <- check_shape(value) do
          {:ok, value}
        else
          {:error, {_line, reason, token}} ->
            {:error, "Could not parse bindings: #{format_parse_error(reason, token)}"}

          {:error, {:unsafe, description}} ->
            {:error,
             "Bindings may only contain literal values (maps, keyword lists, " <>
               "strings, atoms, numbers, booleans, nil). Rejected: " <>
               description <> "."}

          {:error, {:bad_shape, got}} ->
            {:error, "Bindings must evaluate to a map or keyword list, got: " <> inspect(got)}
        end
    end
  end

  # ── AST literal-only check ────────────────────────────────────

  # Whitelist for the sigil carve-out. Each entry is expanded by
  # `Code.eval_quoted/3` into a `Date` / `DateTime` / `NaiveDateTime`
  # struct — pure data, no hidden code paths.
  @allowed_sigils [:sigil_D, :sigil_U, :sigil_N]

  defp check_literal(ast) do
    case ast do
      atom when is_atom(atom) -> :ok
      num when is_number(num) -> :ok
      bin when is_binary(bin) -> :ok
      # `-N` for negative-number literals. The parser emits
      # `{:-, _, [num]}`; unwrap and re-check the inner number.
      {:-, _, [inner]} -> check_literal(inner)
      # Whitelisted date/datetime sigils. The body must be a
      # non-interpolating string (`{:<<>>, _, [binary]}` with
      # exactly one binary element) and the modifier list must be
      # empty. Anything else — interpolation, modifiers, a
      # non-whitelisted sigil name — gets rejected.
      {sigil, _, [{:<<>>, _, [content]}, []]}
      when sigil in @allowed_sigils and is_binary(content) ->
        :ok

      list when is_list(list) -> check_list(list)
      # Two-tuple (keyword pair).
      {a, b} -> with :ok <- check_literal(a), do: check_literal(b)
      # Tuple literal of size > 2, encoded as `{:{}, meta, elems}`.
      {:{}, _, elems} -> check_list(elems)
      # Map literal: `{:%{}, meta, [{k, v}, …]}`.
      {:%{}, _, pairs} -> check_list(pairs)
      other -> {:error, {:unsafe, describe_rejected(other)}}
    end
  end

  defp check_list([]), do: :ok

  defp check_list([head | tail]) do
    with :ok <- check_literal(head), do: check_list(tail)
  end

  # A short description of the rejected AST node so the user sees
  # *why* their input was flagged, without dumping the full AST.
  defp describe_rejected({{:., _, _}, _, _}), do: "function call or module reference"
  defp describe_rejected({name, _, nil}) when is_atom(name), do: "variable `#{name}`"

  # Sigils (besides the whitelisted ~D/~U/~N with empty modifiers):
  # their AST is `{:sigil_X, meta, [<<>>-node, modifier-list]}`.
  # Name them by their sigil letter in the error so "why is my ~r
  # rejected" is self-evident.
  defp describe_rejected({name, _, [_body, _mods]})
       when name in [
              :sigil_r,
              :sigil_R,
              :sigil_s,
              :sigil_S,
              :sigil_c,
              :sigil_C,
              :sigil_w,
              :sigil_W,
              :sigil_T
            ] do
    letter = name |> Atom.to_string() |> String.trim_leading("sigil_")
    "~#{letter} sigil (only ~D, ~U, ~N are allowed)"
  end

  defp describe_rejected({name, _, [_body, mods]}) when name in [:sigil_D, :sigil_U, :sigil_N] and mods != [] do
    letter = name |> Atom.to_string() |> String.trim_leading("sigil_")
    "~#{letter} sigil with modifiers (modifiers aren't allowed)"
  end

  defp describe_rejected({name, _, args}) when is_atom(name) and is_list(args),
    do: "function call `#{name}/#{length(args)}`"

  defp describe_rejected(other), do: "unsupported expression `#{Macro.to_string(other)}`"

  # ── Safe eval (only called after check_literal/1 has passed) ─

  defp safe_eval(ast) do
    try do
      Code.eval_quoted(ast, [], __ENV__)
    rescue
      error -> {:error, {:unsafe, Exception.message(error)}}
    end
  end

  # ── Final shape check (map or keyword list only) ──────────────

  defp check_shape(value) do
    cond do
      is_map(value) -> :ok
      Keyword.keyword?(value) -> :ok
      true -> {:error, {:bad_shape, value}}
    end
  end

  defp format_parse_error(reason, token) when is_binary(reason) and token in [nil, ""], do: reason
  defp format_parse_error(reason, token) when is_binary(reason), do: "#{reason}#{token}"
  defp format_parse_error(reason, _), do: inspect(reason)
end
