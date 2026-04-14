defmodule LocalizePlaygroundWeb.PageLive do
  @moduledoc """
  Main LiveView for the playground. Currently renders the Numbers tab.
  """

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.NumberView

  @style_groups [
    %{id: :decimal, label: "Decimal", hint: "Plain numbers with locale grouping"},
    %{id: :currency, label: "Currency", hint: "Money amounts with currency symbols"},
    %{id: :percent, label: "Percent", hint: "Scaled by 100 with a % sign"},
    %{id: :compact, label: "Compact", hint: "1.2K · 1 million · $1M"},
    %{id: :rbnf, label: "Spellout / RBNF", hint: "\"one hundred twenty-three\""},
    %{id: :range, label: "Range", hint: "3–5 · 1.5–2.5"},
    %{id: :boundary, label: "Approximate", hint: "~5 · 5+ · ≤5"},
    %{id: :pattern, label: "Custom pattern", hint: "Enter a CLDR format string"}
  ]

  @currency_symbol_options [
    {:standard, "Standard ($)"},
    {:iso, "ISO code (USD)"},
    {:narrow, "Narrow ($)"}
  ]

  @rounding_modes [
    :half_even,
    :half_up,
    :half_down,
    :up,
    :down,
    :ceiling,
    :floor
  ]

  @number_systems [
    {:default, "Default for locale"},
    {:native, "Native"},
    {:traditional, "Traditional"},
    {:finance, "Finance"},
    {:latn, "Latin (latn)"},
    {:arab, "Arabic-Indic (arab)"},
    {:arabext, "Extended Arabic-Indic (arabext)"},
    {:deva, "Devanagari (deva)"},
    {:beng, "Bengali (beng)"},
    {:thai, "Thai (thai)"},
    {:hans, "Han simplified (hans)"},
    {:hant, "Han traditional (hant)"},
    {:hansfin, "Han simplified financial (hansfin)"},
    {:hantfin, "Han traditional financial (hantfin)"},
    {:jpan, "Japanese (jpan)"},
    {:jpanfin, "Japanese financial (jpanfin)"},
    {:roman, "Roman (roman)"}
  ]

  @decimal_styles [
    {:standard, "Standard"},
    {:scientific, "Scientific"}
  ]

  @currency_styles [
    {:currency, "Currency"},
    {:accounting, "Accounting"},
    {:currency_no_symbol, "Currency (no symbol)"},
    {:accounting_no_symbol, "Accounting (no symbol)"}
  ]

  @compact_styles [
    {:decimal_short, "Decimal short (1.2K)"},
    {:decimal_long, "Decimal long (1 thousand)"},
    {:currency_short, "Currency short ($1M)"},
    {:currency_long, "Currency long (123 US dollars)"},
    {:currency_long_with_symbol, "Currency long with symbol"}
  ]

  @boundary_styles [
    {:approximately, "Approximately"},
    {:at_least, "At least"},
    {:at_most, "At most"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:style_groups, @style_groups)
      |> assign(:currency_symbol_options, @currency_symbol_options)
      |> assign(:rounding_modes, @rounding_modes)
      |> assign(:decimal_styles, @decimal_styles)
      |> assign(:currency_styles, @currency_styles)
      |> assign(:compact_styles, @compact_styles)
      |> assign(:boundary_styles, @boundary_styles)
      |> assign(:number_systems, @number_systems)
      |> assign(:locale_options, NumberView.locale_options())
      |> assign(:currency_options, NumberView.currency_options())
      |> assign_defaults()
      |> compute_output()

    {:ok, socket}
  end

  defp assign_defaults(socket) do
    socket
    |> assign(:locale, "en")
    |> assign(:number, "1234.56")
    |> assign(:range_end, "5678.90")
    |> assign(:style_group, :decimal)
    |> assign(:decimal_style, :standard)
    |> assign(:currency_style, :currency)
    |> assign(:compact_style, :decimal_short)
    |> assign(:boundary_kind, :approximately)
    |> assign(:currency, "USD")
    |> assign(:currency_symbol, :standard)
    |> assign(:rbnf_rule, "spellout_cardinal")
    |> assign(:custom_pattern, "#,##0.00;(#,##0.00)")
    |> assign(:min_fractional_digits, "")
    |> assign(:max_fractional_digits, "")
    |> assign(:rounding_mode, :half_even)
    |> assign(:round_nearest, "")
    |> assign(:number_system, :default)
    |> assign(:u_extensions, %{})
    |> assign(:rbnf_rules, NumberView.rbnf_rules("en"))
  end

  @impl true
  def handle_event("update", params, socket) do
    previous_locale = socket.assigns.locale
    socket = apply_params(socket, params)
    locale_changed? = socket.assigns.locale != previous_locale

    socket =
      socket
      |> maybe_apply_u_extensions(locale_changed?)
      |> refresh_rbnf_rules_if_needed()
      |> compute_output()

    {:noreply, socket}
  end

  defp maybe_apply_u_extensions(socket, false), do: socket

  defp maybe_apply_u_extensions(socket, true) do
    case NumberView.u_extensions(socket.assigns.locale) do
      {:ok, extensions} ->
        socket
        |> assign(:u_extensions, extensions)
        |> maybe_apply(:number_system, Map.get(extensions, :nu))
        |> maybe_apply_currency(Map.get(extensions, :cu))

      :error ->
        assign(socket, :u_extensions, %{})
    end
  end

  defp maybe_apply(socket, _key, nil), do: socket
  defp maybe_apply(socket, key, value), do: assign(socket, key, value)

  defp maybe_apply_currency(socket, nil), do: socket

  defp maybe_apply_currency(socket, currency) do
    assign(socket, :currency, currency |> Atom.to_string() |> String.upcase())
  end

  defp apply_params(socket, params) do
    string_keys = [
      "locale",
      "number",
      "range_end",
      "currency",
      "rbnf_rule",
      "custom_pattern",
      "min_fractional_digits",
      "max_fractional_digits",
      "round_nearest"
    ]

    atom_keys = [
      {"style_group", &atomize_style_group/1},
      {"decimal_style", &atomize/1},
      {"currency_style", &atomize/1},
      {"compact_style", &atomize/1},
      {"boundary_kind", &atomize/1},
      {"currency_symbol", &atomize/1},
      {"rounding_mode", &atomize/1},
      {"number_system", &atomize/1}
    ]

    socket =
      Enum.reduce(string_keys, socket, fn key, acc ->
        case Map.fetch(params, key) do
          {:ok, value} -> assign(acc, String.to_atom(key), value)
          :error -> acc
        end
      end)

    Enum.reduce(atom_keys, socket, fn {key, converter}, acc ->
      case Map.fetch(params, key) do
        {:ok, value} when is_binary(value) and value != "" ->
          assign(acc, String.to_atom(key), converter.(value))

        _ ->
          acc
      end
    end)
  end

  defp refresh_rbnf_rules_if_needed(socket) do
    rules = NumberView.rbnf_rules(socket.assigns.locale)
    rule = socket.assigns.rbnf_rule

    rule =
      cond do
        rules == [] -> rule
        rule in rules -> rule
        true -> List.first(rules) || rule
      end

    socket
    |> assign(:rbnf_rules, rules)
    |> assign(:rbnf_rule, rule)
  end

  defp atomize(value) when is_binary(value), do: String.to_existing_atom(value)

  defp atomize_style_group(value) when is_binary(value) do
    known = Enum.map(@style_groups, & &1.id)

    try do
      atom = String.to_existing_atom(value)
      if atom in known, do: atom, else: :decimal
    rescue
      ArgumentError -> :decimal
    end
  end

  # --- output computation ---

  defp compute_output(socket) do
    assigns = socket.assigns

    locale = normalize_locale(assigns.locale)
    number_result = NumberView.parse_number(assigns.number)

    {style_atom, options, pattern_style} = build_options(assigns, locale)

    {result, pattern, meta} =
      case {assigns.style_group, number_result} do
        {_, {:error, message}} ->
          {{:error, message}, nil, nil}

        {:rbnf, {:ok, number}} ->
          result = NumberView.format_rbnf(number, assigns.rbnf_rule, locale)
          {result, :rbnf, {:rbnf, assigns.rbnf_rule}}

        {:range, {:ok, number}} ->
          case NumberView.parse_number(assigns.range_end) do
            {:ok, range_end} ->
              result = NumberView.format_range(number, range_end, options)
              {pattern_value, meta_value} = resolve_pattern_and_meta(locale, pattern_style)
              {result, pattern_value, meta_value}

            {:error, message} ->
              {{:error, "Range end: " <> message}, nil, nil}
          end

        {:boundary, {:ok, number}} ->
          result = NumberView.format_boundary(assigns.boundary_kind, number, options)
          {pattern_value, meta_value} = resolve_pattern_and_meta(locale, pattern_style)
          {result, pattern_value, meta_value}

        {:pattern, {:ok, number}} ->
          result = NumberView.format(number, options)
          pattern = assigns.custom_pattern

          meta =
            case NumberView.pattern_metadata(pattern) do
              {:ok, meta} -> meta
              {:error, _} -> nil
            end

          {result, pattern, meta}

        {_, {:ok, number}} ->
          result = NumberView.format(number, options)
          {pattern_value, meta_value} = resolve_pattern_and_meta(locale, pattern_style)
          {result, pattern_value, meta_value}
      end

    socket
    |> assign(:result, result)
    |> assign(:pattern, pattern)
    |> assign(:pattern_meta, meta)
    |> assign(:locale_symbols, NumberView.locale_symbols(locale, non_default(assigns.number_system)))
    |> assign(:call_code, build_call_code(assigns, number_result, options))
    |> assign(:options_for_display, sanitize_options_for_display(options, style_atom))
  end

  defp build_call_code(assigns, number_result, options) do
    number_arg =
      case number_result do
        {:ok, n} -> inspect(n)
        {:error, _} -> inspect(assigns.number)
      end

    display_options = strip_default_options(options)

    case assigns.style_group do
      :range ->
        end_arg =
          case NumberView.parse_number(assigns.range_end) do
            {:ok, n} -> inspect(n)
            _ -> inspect(assigns.range_end)
          end

        "Localize.Number.to_range_string(#{number_arg}, #{end_arg}#{trailing_kw(display_options)})"

      :boundary ->
        fun =
          case assigns.boundary_kind do
            :approximately -> "to_approximately_string"
            :at_least -> "to_at_least_string"
            :at_most -> "to_at_most_string"
          end

        "Localize.Number.#{fun}(#{number_arg}#{trailing_kw(display_options)})"

      :rbnf ->
        rule = inspect(assigns.rbnf_rule)
        locale_opts = if to_string(assigns.locale) == "en", do: [], else: [locale: to_string(assigns.locale)]
        "Localize.Number.Rbnf.to_string(#{number_arg}, #{rule}#{trailing_kw(locale_opts)})"

      _ ->
        "Localize.Number.to_string(#{number_arg}#{trailing_kw(display_options)})"
    end
  end

  # Drop options whose value equals the Localize default, so the generated
  # call reads as what the user meaningfully changed from the baseline.
  defp strip_default_options(options) do
    Enum.reject(options, fn {key, value} -> default_option?(key, value) end)
  end

  defp default_option?(:locale, "en"), do: true
  defp default_option?(:locale, :en), do: true
  defp default_option?(:format, :standard), do: true
  defp default_option?(:rounding_mode, :half_even), do: true
  defp default_option?(:currency_symbol, :standard), do: true
  defp default_option?(:number_system, :default), do: true
  defp default_option?(_, _), do: false

  defp trailing_kw([]), do: ""

  defp trailing_kw(options) do
    ", " <>
      (options
       |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
       |> Enum.join(", "))
  end


  defp build_options(assigns, locale) do
    base = [locale: locale]
    {style_atom, style_base} = style_option(assigns)

    currency_opts =
      if assigns.style_group in [:currency, :compact] and style_atom in currency_styles() do
        [currency: String.to_atom(assigns.currency)] ++
          currency_symbol_option(assigns.currency_symbol)
      else
        []
      end

    numeric_opts =
      []
      |> maybe_add(:min_fractional_digits, parse_nonneg_int(assigns.min_fractional_digits))
      |> maybe_add(:max_fractional_digits, parse_nonneg_int(assigns.max_fractional_digits))
      |> maybe_add(:round_nearest, parse_nonneg_int(assigns.round_nearest))
      |> maybe_add(:rounding_mode, assigns.rounding_mode)
      |> maybe_add(:number_system, non_default(assigns.number_system))

    options = base ++ style_base ++ currency_opts ++ numeric_opts
    {style_atom, options, pattern_style_for(assigns, style_atom)}
  end

  defp style_option(%{style_group: :decimal, decimal_style: s}), do: {s, [format: s]}
  defp style_option(%{style_group: :currency, currency_style: s}), do: {s, [format: s]}
  defp style_option(%{style_group: :percent}), do: {:percent, [format: :percent]}
  defp style_option(%{style_group: :compact, compact_style: s}), do: {s, [format: s]}
  defp style_option(%{style_group: :range, decimal_style: s}), do: {s, [format: s]}
  defp style_option(%{style_group: :boundary, decimal_style: s}), do: {s, [format: s]}
  defp style_option(%{style_group: :rbnf}), do: {:standard, []}

  defp style_option(%{style_group: :pattern, custom_pattern: pattern}),
    do: {:custom, [format: pattern]}

  defp pattern_style_for(%{style_group: :percent}, _), do: :percent
  defp pattern_style_for(%{style_group: :rbnf}, _), do: nil
  defp pattern_style_for(%{style_group: :pattern}, _), do: nil
  defp pattern_style_for(_, style_atom), do: style_atom

  defp currency_styles do
    [
      :currency,
      :accounting,
      :currency_no_symbol,
      :accounting_no_symbol,
      :currency_short,
      :currency_long,
      :currency_long_with_symbol
    ]
  end

  defp currency_symbol_option(nil), do: []
  defp currency_symbol_option(:standard), do: []
  defp currency_symbol_option(value), do: [currency_symbol: value]

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, _key, ""), do: list
  defp maybe_add(list, key, value), do: list ++ [{key, value}]

  defp parse_nonneg_int(""), do: nil
  defp parse_nonneg_int(nil), do: nil

  defp parse_nonneg_int(string) when is_binary(string) do
    case Integer.parse(String.trim(string)) do
      {int, ""} when int >= 0 -> int
      _ -> nil
    end
  end

  defp parse_nonneg_int(int) when is_integer(int) and int >= 0, do: int
  defp parse_nonneg_int(_), do: nil

  defp non_default(:default), do: nil
  defp non_default(value), do: value

  defp resolve_pattern_and_meta(_locale, nil), do: {nil, nil}

  defp resolve_pattern_and_meta(locale, style) do
    case NumberView.resolve_pattern(locale, style) do
      {:ok, pattern} when is_binary(pattern) ->
        meta =
          case NumberView.pattern_metadata(pattern) do
            {:ok, m} -> m
            _ -> nil
          end

        {pattern, meta}

      {:ok, other} ->
        {other, nil}

      {:error, message} ->
        {{:error, message}, nil}
    end
  end

  defp normalize_locale(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: :en, else: trimmed
  end

  defp sanitize_options_for_display(options, _style) do
    options
  end

  # ---- render ----

  @impl true
  def render(assigns) do
    LocalizePlaygroundWeb.NumbersLive.render(assigns)
  end
end
