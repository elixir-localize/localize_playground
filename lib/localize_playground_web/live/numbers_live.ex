defmodule LocalizePlaygroundWeb.NumbersLive do
  @moduledoc """
  Renders the Numbers tab. All state lives in the parent `PageLive`;
  this module is a pure `render/1` target that emits HEEx markup.

  """

  use LocalizePlaygroundWeb, :html

  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <div class="lp-dt-top">
        <.field label={gettext("Locale")} for="locale" hint={gettext("Type a CLDR locale such as en, de, zh-Hant")}>
          <input
            id="locale"
            name="locale"
            type="text"
            list="locales"
            value={@locale}
            phx-debounce="150"
          />
          <datalist id="locales">
            <option :for={locale <- @locale_options} value={locale}></option>
          </datalist>
        </.field>
      </div>

      <div class="lp-top-row">
        <.field :if={@style_group != :range} label={gettext("Number")} for="number">
          <input
            id="number"
            name="number"
            type="text"
            value={@number}
            inputmode="decimal"
            phx-debounce="150"
          />
        </.field>

        <.field :if={@style_group == :range} label={gettext("Range start")} for="number">
          <input
            id="number"
            name="number"
            type="text"
            value={@number}
            inputmode="decimal"
            phx-debounce="150"
          />
        </.field>

        <.field :if={@style_group == :range} label={gettext("Range end")} for="range_end">
          <input
            id="range_end"
            name="range_end"
            type="text"
            value={@range_end}
            inputmode="decimal"
            phx-debounce="150"
          />
        </.field>
      </div>

      <.section title={gettext("Formatted number")} class="lp-result-section">
        <.call_code_card code={@call_code} />
        <.result_card result={@result} />
      </.section>

      <.section title={gettext("Format family")}>
        <div class="lp-radio-cards">
          <label :for={group <- @style_groups} class={radio_card_class(group.id, @style_group)}>
            <input
              type="radio"
              name="style_group"
              value={group.id}
              checked={@style_group == group.id}
            />
            <span class="lp-radio-title">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", group.label)}</span>
            <span class="lp-radio-hint">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", group.hint)}</span>
          </label>
        </div>
      </.section>

      <.section title={gettext("Format options")}>
        <div class="lp-sub-controls">
          <%= case @style_group do %>
            <% :decimal -> %>
              <.field label={gettext("Style")}>
                <select name="decimal_style">
                  <option :for={{value, label} <- @decimal_styles} value={value} selected={@decimal_style == value}>
                    {label}
                  </option>
                </select>
              </.field>
            <% :currency -> %>
              <.field label={gettext("Style")}>
                <select name="currency_style">
                  <option :for={{value, label} <- @currency_styles} value={value} selected={@currency_style == value}>
                    {label}
                  </option>
                </select>
              </.field>
              <.field label={gettext("Currency")} for="currency" hint={gettext("ISO 4217 code")}>
                <input
                  id="currency"
                  name="currency"
                  type="text"
                  list="currencies"
                  value={@currency}
                  phx-debounce="150"
                />
                <datalist id="currencies">
                  <option :for={code <- @currency_options} value={code}></option>
                </datalist>
              </.field>
              <.field label={gettext("Currency symbol")}>
                <select name="currency_symbol">
                  <option :for={{value, label} <- @currency_symbol_options} value={value} selected={@currency_symbol == value}>
                    {label}
                  </option>
                </select>
              </.field>
            <% :compact -> %>
              <.field label={gettext("Style")}>
                <select name="compact_style">
                  <option :for={{value, label} <- @compact_styles} value={value} selected={@compact_style == value}>
                    {label}
                  </option>
                </select>
              </.field>
              <.field :if={currency_compact?(@compact_style)} label={gettext("Currency")} for="currency">
                <input
                  id="currency"
                  name="currency"
                  type="text"
                  list="currencies"
                  value={@currency}
                  phx-debounce="150"
                />
                <datalist id="currencies">
                  <option :for={code <- @currency_options} value={code}></option>
                </datalist>
              </.field>
            <% :rbnf -> %>
              <.field label={gettext("RBNF rule")} hint={gettext("Rule sets vary by locale")}>
                <select name="rbnf_rule">
                  <option :if={@rbnf_rules == []} value="">(none available)</option>
                  <option :for={name <- @rbnf_rules} value={name} selected={@rbnf_rule == name}>
                    {name}
                  </option>
                </select>
              </.field>
            <% :range -> %>
              <.field label={gettext("Style")}>
                <select name="decimal_style">
                  <option :for={{value, label} <- @decimal_styles} value={value} selected={@decimal_style == value}>
                    {label}
                  </option>
                </select>
              </.field>
            <% :boundary -> %>
              <.field label={gettext("Boundary")}>
                <select name="boundary_kind">
                  <option :for={{value, label} <- @boundary_styles} value={value} selected={@boundary_kind == value}>
                    {label}
                  </option>
                </select>
              </.field>
            <% :pattern -> %>
              <.field label={gettext("Custom pattern")} for="custom_pattern" hint={gettext("CLDR format, e.g. #,##0.00;(#,##0.00)")}>
                <input
                  id="custom_pattern"
                  name="custom_pattern"
                  type="text"
                  value={@custom_pattern}
                  class="lp-pattern-input"
                  phx-debounce="150"
                />
              </.field>
            <% _ -> %>
              <div></div>
          <% end %>
        </div>

        <div class="lp-advanced-options">
          <h3 class="lp-advanced-options-title">{gettext("Advanced formatting options")}</h3>
          <div class="lp-sub-controls">
            <.field label={gettext("Min fractional digits")} for="min_fractional_digits">
              <input
                id="min_fractional_digits"
                name="min_fractional_digits"
                type="number"
                min="0"
                max="20"
                value={@min_fractional_digits}
                placeholder={gettext("auto")}
                phx-debounce="150"
              />
            </.field>
            <.field label={gettext("Max fractional digits")} for="max_fractional_digits">
              <input
                id="max_fractional_digits"
                name="max_fractional_digits"
                type="number"
                min="0"
                max="20"
                value={@max_fractional_digits}
                placeholder={gettext("auto")}
                phx-debounce="150"
              />
            </.field>
            <.field label={gettext("Rounding mode")}>
              <select name="rounding_mode">
                <option :for={mode <- @rounding_modes} value={mode} selected={@rounding_mode == mode}>
                  {humanize_atom(mode)}
                </option>
              </select>
            </.field>
            <.field label={gettext("Round nearest")} for="round_nearest">
              <input
                id="round_nearest"
                name="round_nearest"
                type="number"
                min="0"
                value={@round_nearest}
                placeholder={gettext("off")}
                phx-debounce="150"
              />
            </.field>
            <.field label={gettext("Number system")} hint={gettext("Auto-set by a locale's -u-nu- subtag")}>
              <select name="number_system">
                <option :for={{value, label} <- @number_systems} value={value} selected={@number_system == value}>
                  {label}
                </option>
              </select>
            </.field>
          </div>
        </div>
      </.section>
    </form>

    <.section title={gettext("Format pattern")}>
      <.pattern_card pattern={@pattern} />
    </.section>

    <.section title={gettext("Pattern metadata")}>
      <.meta_card meta={@pattern_meta} />
    </.section>

    <.section :if={map_size(@u_extensions) > 0} title={gettext("Locale U-extensions (applied automatically)")}>
      <.u_extensions_card extensions={@u_extensions} />
    </.section>

    <.section title={gettext("Locale metadata")}>
      <.locale_metadata_card symbols={@locale_symbols} locale={@locale} />
    </.section>
    """
  end

  attr :result, :any, required: true

  defp result_card(%{result: {:ok, _}} = assigns) do
    ~H"""
    <div class="lp-result">{elem(@result, 1)}</div>
    """
  end

  defp result_card(%{result: {:error, _}} = assigns) do
    ~H"""
    <div class="lp-error">
      <strong>{gettext("Error:")}</strong> {elem(@result, 1)}
    </div>
    """
  end

  defp result_card(assigns) do
    ~H"""
    <div class="lp-result lp-muted">—</div>
    """
  end

  attr :pattern, :any, required: true

  defp pattern_card(%{pattern: nil} = assigns) do
    ~H"""
    <div class="lp-pattern lp-muted">No pattern applies for this style.</div>
    """
  end

  defp pattern_card(%{pattern: :rbnf} = assigns) do
    ~H"""
    <div class="lp-pattern lp-muted">
      Rule-based (RBNF) — no format pattern; see rule name in metadata.
    </div>
    """
  end

  defp pattern_card(%{pattern: {:error, _}} = assigns) do
    ~H"""
    <div class="lp-error">
      <strong>{gettext("Could not resolve pattern:")}</strong> {elem(@pattern, 1)}
    </div>
    """
  end

  defp pattern_card(%{pattern: pattern} = assigns) when is_binary(pattern) do
    ~H"""
    <div class="lp-pattern"><code>{@pattern}</code></div>
    """
  end

  defp pattern_card(%{pattern: pattern} = assigns) when is_map(pattern) do
    # Compact formats come as a map of magnitude → plural rules
    ~H"""
    <div class="lp-pattern-map">
      <p class="lp-muted">Compact patterns by magnitude (powers of 10) and plural category:</p>
      <pre class="lp-export">{inspect(@pattern, pretty: true, width: 60, limit: :infinity)}</pre>
    </div>
    """
  end

  defp pattern_card(assigns) do
    ~H"""
    <div class="lp-pattern"><code>{inspect(@pattern)}</code></div>
    """
  end

  attr :meta, :any, required: true

  defp meta_card(%{meta: nil} = assigns) do
    ~H"""
    <div class="lp-muted">—</div>
    """
  end

  defp meta_card(%{meta: {:rbnf, rule}} = assigns) do
    assigns = assign(assigns, :rule, rule)

    ~H"""
    <dl class="lp-meta-table">
      <dt>{gettext("Kind")}</dt>
      <dd>Rule-based number format (RBNF)</dd>
      <dt>{gettext("Rule name")}</dt>
      <dd><code>{@rule}</code></dd>
    </dl>
    """
  end

  defp meta_card(%{meta: meta} = assigns) when is_map(meta) do
    assigns = assign(assigns, :m, meta)

    ~H"""
    <dl class="lp-meta-table">
      <dt>{gettext("Integer digits")}</dt>
      <dd>min: {@m.integer_digits.min} · max: {@m.integer_digits.max}</dd>

      <dt>{gettext("Fractional digits")}</dt>
      <dd>min: {@m.fractional_digits.min} · max: {@m.fractional_digits.max}</dd>

      <dt :if={@m.significant_digits.max > 0}>Significant digits</dt>
      <dd :if={@m.significant_digits.max > 0}>
        min: {@m.significant_digits.min} · max: {@m.significant_digits.max}
      </dd>

      <dt>{gettext("Integer grouping")}</dt>
      <dd>{grouping_sentence(@m.grouping.integer)}</dd>

      <dt :if={@m.grouping.fraction.first > 0}>Fraction grouping</dt>
      <dd :if={@m.grouping.fraction.first > 0}>
        {grouping_sentence(@m.grouping.fraction, :fraction)}
      </dd>

      <dt>{gettext("Multiplier")}</dt>
      <dd>{multiplier_sentence(@m.multiplier)}</dd>

      <dt :if={@m.exponent_digits > 0}>Exponent digits</dt>
      <dd :if={@m.exponent_digits > 0}>{@m.exponent_digits}</dd>

      <dt :if={@m.round_nearest != 0}>{gettext("Round nearest")}</dt>
      <dd :if={@m.round_nearest != 0}>{@m.round_nearest}</dd>
    </dl>
    """
  end

  defp meta_card(assigns) do
    ~H"""
    <pre class="lp-export">{inspect(@meta, pretty: true, width: 60, limit: :infinity)}</pre>
    """
  end

  defp radio_card_class(id, current) do
    if id == current, do: "lp-radio-card active", else: "lp-radio-card"
  end

  defp currency_compact?(style) do
    style in [:currency_short, :currency_long, :currency_long_with_symbol]
  end

  @doc false
  def humanize_atom(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  def humanize_atom(other), do: to_string(other)

  attr :code, :string, required: true

  defp call_code_card(assigns) do
    ~H"""
    <div class="lp-call-code" phx-hook="CopyToClipboard" id="call-code-wrapper">
      <LocalizePlaygroundWeb.HexDocs.code code={@code} id="call-code-text" />
      <button
        type="button"
        class="lp-copy-btn"
        aria-label={gettext("Copy function call to clipboard")}
        data-copy-target="#call-code-text"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <rect x="4" y="4" width="9" height="9" rx="1.5" />
          <path d="M10.5 4V2.5A1.5 1.5 0 0 0 9 1H3.5A1.5 1.5 0 0 0 2 2.5V8a1.5 1.5 0 0 0 1.5 1.5H4" />
        </svg>
        <span class="lp-copy-label">{gettext("Copy")}</span>
      </button>
    </div>
    """
  end

  defp grouping_sentence(grouping, side \\ :integer)

  defp grouping_sentence(%{first: 0, rest: 0}, _side),
    do: "No grouping applied."

  defp grouping_sentence(%{first: first, rest: 0}, side) do
    "First group is #{number_word(first)} #{digit_word(first)} from the #{pivot(side)}; " <>
      "no further grouping after that."
  end

  defp grouping_sentence(%{first: first, rest: rest}, side) when first == rest do
    "Every group is #{number_word(first)} #{digit_word(first)} wide, " <>
      "starting from the #{pivot(side)}."
  end

  defp grouping_sentence(%{first: first, rest: rest}, side) do
    "First group is #{number_word(first)} #{digit_word(first)} from the #{pivot(side)}; " <>
      "subsequent groups are #{number_word(rest)} #{digit_word(rest)} wide."
  end

  defp multiplier_sentence(1), do: "1 (the number is used as-is)"
  defp multiplier_sentence(100), do: "100 (the number is multiplied by 100, as in a percentage)"
  defp multiplier_sentence(1000), do: "1000 (the number is multiplied by 1000, as in per-mille)"
  defp multiplier_sentence(n), do: "#{n} (the number is multiplied by #{n})"

  defp pivot(:integer), do: "decimal point"
  defp pivot(:fraction), do: "decimal point"

  defp digit_word(1), do: "digit"
  defp digit_word(_), do: "digits"

  defp number_word(0), do: "zero"
  defp number_word(1), do: "one"
  defp number_word(2), do: "two"
  defp number_word(3), do: "three"
  defp number_word(4), do: "four"
  defp number_word(5), do: "five"
  defp number_word(6), do: "six"
  defp number_word(7), do: "seven"
  defp number_word(8), do: "eight"
  defp number_word(9), do: "nine"
  defp number_word(n), do: Integer.to_string(n)

  attr :symbols, :any, required: true
  attr :locale, :string, required: true

  defp locale_metadata_card(%{symbols: nil} = assigns) do
    ~H"""
    <div class="lp-muted">No symbol data available for locale {inspect(@locale)}.</div>
    """
  end

  defp locale_metadata_card(%{symbols: {system, symbols}} = assigns) do
    rows = [
      {gettext("Number system"), :number_system, system},
      {gettext("Decimal separator"), :decimal, symbols.decimal},
      {gettext("Grouping separator"), :group, symbols.group},
      {gettext("Minus sign"), :minus_sign, symbols.minus_sign},
      {gettext("Plus sign"), :plus_sign, symbols.plus_sign},
      {gettext("Percent sign"), :percent_sign, symbols.percent_sign},
      {gettext("Per-mille sign"), :per_mille, symbols.per_mille},
      {gettext("Exponential"), :exponential, symbols.exponential},
      {gettext("Superscripting exponent"), :superscripting_exponent, symbols.superscripting_exponent},
      {gettext("Infinity"), :infinity, symbols.infinity},
      {gettext("Not-a-number"), :nan, symbols.nan},
      {gettext("Approximately sign"), :approximately_sign, symbols.approximately_sign},
      {gettext("List separator"), :list, symbols.list},
      {gettext("Time separator"), :time_separator, symbols.time_separator}
    ]

    rows = Enum.reject(rows, fn {_label, _key, value} -> value in [nil, ""] end)
    assigns = assign(assigns, :rows, rows)

    ~H"""
    <table class="lp-table">
      <thead>
        <tr>
          <th>{gettext("Symbol")}</th>
          <th>{gettext("Field")}</th>
          <th>{gettext("Value")}</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={{label, key, value} <- @rows}>
          <td>{label}</td>
          <td><code>{key}</code></td>
          <td class="lp-table-value">{render_symbol(value)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp render_symbol(nil), do: Phoenix.HTML.raw("<span class=\"lp-muted\">—</span>")

  defp render_symbol(%{standard: value} = variants) when map_size(variants) == 1 do
    render_symbol(value)
  end

  defp render_symbol(%{} = variants) do
    variants
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join(" · ")
  end

  defp render_symbol(value) when is_binary(value) do
    Phoenix.HTML.raw("<code>#{Phoenix.HTML.html_escape(value) |> Phoenix.HTML.safe_to_string()}</code>")
  end

  defp render_symbol(value), do: inspect(value)

  @u_extension_labels %{
    nu: "Number system (-u-nu)",
    cu: "Currency (-u-cu)",
    ca: "Calendar (-u-ca)",
    co: "Collation (-u-co)",
    hc: "Hour cycle (-u-hc)",
    fw: "First day of week (-u-fw)",
    rg: "Region override (-u-rg)",
    tz: "Time zone (-u-tz)",
    va: "Variant (-u-va)"
  }

  attr :extensions, :map, required: true

  defp u_extensions_card(assigns) do
    rows =
      assigns.extensions
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map(fn {k, v} ->
        label = Map.get(@u_extension_labels, k, "-u-#{k}")
        {label, k, v}
      end)

    assigns = assign(assigns, :rows, rows)

    ~H"""
    <table class="lp-table">
      <thead>
        <tr>
          <th>{gettext("Subtag")}</th>
          <th>Key</th>
          <th>{gettext("Value")}</th>
        </tr>
      </thead>
      <tbody>
        <tr :for={{label, key, value} <- @rows}>
          <td>{label}</td>
          <td><code>{key}</code></td>
          <td class="lp-table-value"><code>{inspect(value)}</code></td>
        </tr>
      </tbody>
    </table>
    """
  end
end
