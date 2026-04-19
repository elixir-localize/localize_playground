defmodule LocalizePlaygroundWeb.ListsLive do
  @moduledoc """
  Lists tab — exposes `Localize.List.to_string/2` and the CLDR list
  patterns. Users provide a list of items and pick a style (`:standard`,
  `:or`, `:unit` and their short/narrow variants) to see how CLDR joins
  them in different locales.
  """

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.NumberView

  # The nine CLDR list style atoms. Each one maps to a different
  # grammatical function: :standard for conjunctions ("A, B, and C"),
  # :or for alternatives ("A, B, or C"), :unit for measurement units
  # ("1 ft 3 in"), each with short and narrow widths.
  @styles [
    {:standard, gettext_noop("standard"),
     gettext_noop("\"A, B, and C\" — default conjunctive list (long width).")},
    {:standard_short, gettext_noop("standard_short"),
     gettext_noop("Shorter punctuation and conjunction form of standard.")},
    {:standard_narrow, gettext_noop("standard_narrow"),
     gettext_noop("Narrowest conjunctive form — may omit conjunction altogether.")},
    {:or, gettext_noop("or"), gettext_noop("\"A, B, or C\" — default disjunctive list.")},
    {:or_short, gettext_noop("or_short"), gettext_noop("Shorter disjunctive form.")},
    {:or_narrow, gettext_noop("or_narrow"), gettext_noop("Narrowest disjunctive form.")},
    {:unit, gettext_noop("unit"),
     gettext_noop("\"1 foot, 3 inches\" — for combining measurement unit values.")},
    {:unit_short, gettext_noop("unit_short"),
     gettext_noop("\"1 ft, 3 in\" — shorter unit combination.")},
    {:unit_narrow, gettext_noop("unit_narrow"),
     gettext_noop("\"1ft 3in\" — narrowest unit combination.")}
  ]

  @examples [
    %{name: gettext_noop("Three colours"), items: "red\ngreen\nblue", style: :standard},
    %{name: gettext_noop("Two choices"), items: "tea\ncoffee", style: :or},
    %{
      name: gettext_noop("Weekdays"),
      items: "Monday\nTuesday\nWednesday\nThursday\nFriday",
      style: :standard
    },
    %{name: gettext_noop("Mixed types"), items: "1\n2.5\nthree", style: :standard},
    %{
      name: gettext_noop("Many items"),
      items: "apple\nbanana\ncherry\ndate\nelderberry\nfig",
      style: :or
    }
  ]

  @impl true
  def mount(params, _session, socket) do
    locale =
      case Map.get(params, "locale") do
        nil -> "en"
        "" -> "en"
        other -> other
      end

    socket =
      socket
      |> assign(:locale, locale)
      |> assign(:current_locale, locale)
      |> assign(:locale_options, NumberView.locale_options())
      |> assign(:styles, @styles)
      |> assign(:examples, @examples)
      |> assign(:style, :standard)
      |> assign(:items_text, "red\ngreen\nblue")
      |> assign(:treat_middle_as_end, false)
      |> compute()

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    socket =
      socket
      |> maybe_assign(params, "locale", :locale)
      |> maybe_assign(params, "items_text", :items_text)
      |> apply_style(params)
      |> assign(:treat_middle_as_end, params["treat_middle_as_end"] == "true")
      |> assign(
        :current_locale,
        if(params["locale"] in [nil, ""],
          do: socket.assigns.current_locale,
          else: params["locale"]
        )
      )
      |> compute()

    {:noreply, socket}
  end

  def handle_event("load_example", %{"index" => index_str}, socket) do
    case Enum.at(@examples, String.to_integer(index_str)) do
      nil ->
        {:noreply, socket}

      example ->
        socket =
          socket
          |> assign(:items_text, example.items)
          |> assign(:style, example.style)
          |> compute()

        {:noreply, socket}
    end
  end

  defp maybe_assign(socket, params, key, assign_key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) -> assign(socket, assign_key, value)
      _ -> socket
    end
  end

  defp apply_style(socket, params) do
    case Map.get(params, "style") do
      nil ->
        socket

      "" ->
        socket

      value ->
        try do
          assign(socket, :style, String.to_existing_atom(value))
        rescue
          ArgumentError -> socket
        end
    end
  end

  defp compute(socket) do
    a = socket.assigns

    items = parse_items(a.items_text)

    options =
      [locale: a.locale, list_style: a.style] ++
        if(a.treat_middle_as_end, do: [treat_middle_as_end: true], else: [])

    result =
      case items do
        [] ->
          {:error, "Enter at least one item (one per line)."}

        _ ->
          case Localize.List.to_string(items, options) do
            {:ok, string} -> {:ok, string}
            {:error, exception} -> {:error, Exception.message(exception)}
          end
      end

    pattern_info = load_pattern(a.locale, a.style)

    socket
    |> assign(:items, items)
    |> assign(:result, result)
    |> assign(:pattern, pattern_info)
    |> assign(:call_code, build_call_code(items, a))
  end

  defp parse_items(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp load_pattern(locale, style) do
    case Localize.List.list_patterns_for(locale) do
      {:ok, patterns} -> Map.get(patterns, style)
      _ -> nil
    end
  end

  defp build_call_code(items, %{locale: locale, style: style, treat_middle_as_end: middle_as_end}) do
    opts = [locale: inspect(to_string(locale)), list_style: inspect(style)]
    opts = if middle_as_end, do: opts ++ [treat_middle_as_end: "true"], else: opts

    options_str = opts |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
    items_str = inspect(items)

    "Localize.List.to_string(\n  #{items_str},\n  #{options_str}\n)"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title={gettext("List")}>
        <div class="lp-dt-top">
          <.field label={gettext("Locale")} for="locale">
            <input id="locale" name="locale" type="text" list="list-locales" value={@locale} phx-debounce="200" />
            <datalist id="list-locales">
              <option :for={l <- @locale_options} value={l}></option>
            </datalist>
          </.field>
        </div>
      </.section>

      <.section title={gettext("Formatted output")} class="lp-result-section">
        <.result_card result={@result} />
        <.call_code code={@call_code} id="list-call" />
      </.section>

      <.section title={gettext("Items")}>
        <.field label={gettext("Items (one per line)")} for="items_text" hint={gettext("Each line becomes one element in the list.")}>
          <textarea id="items_text" name="items_text" class="lp-mf2-bindings" rows="5" spellcheck="false" phx-debounce="200">{@items_text}</textarea>
        </.field>
      </.section>

      <.section title={gettext("List style")}>
        <p class="lp-muted lp-help-text">
          {gettext("CLDR provides three list families — standard (conjunctive), or (disjunctive), and unit (measurement) — each in three widths. Pick a style below to see how the join pattern changes.")}
        </p>

        <div class="lp-radio-cards lp-radio-cards-3col">
          <label :for={{id, label, hint} <- @styles} class={"lp-radio-card" <> if(@style == id, do: " active", else: "")}>
            <input type="radio" name="style" value={id} checked={@style == id} />
            <span class="lp-radio-title"><code>:{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", label)}</code></span>
            <span class="lp-radio-hint">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", hint)}</span>
          </label>
        </div>

        <label class="lp-checkbox-row">
          <input type="checkbox" name="treat_middle_as_end" value="true" checked={@treat_middle_as_end} />
          <span>{gettext("Treat the last joiner as middle (omit the final conjunction)")}</span>
        </label>
      </.section>

      <.section :if={@pattern} title={gettext("Pattern for this locale × style")}>
        <p class="lp-muted lp-help-text">
          {gettext("CLDR list patterns use four slots — start, middle, end, and the special two-item pattern for lists of exactly two. `{0}` and `{1}` are substituted with list elements.")}
        </p>
        <.pattern_card pattern={@pattern} />
      </.section>

      <.section title={gettext("Examples")}>
        <div class="lp-mf2-toolbar">
          <div class="lp-mf2-examples">
            <button
              :for={{example, index} <- Enum.with_index(@examples)}
              type="button"
              class="lp-mf2-example-btn"
              phx-click="load_example"
              phx-value-index={index}
            >
              {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", example.name)}
            </button>
          </div>
        </div>
      </.section>
    </form>
    """
  end

  attr(:code, :string, required: true)
  attr(:id, :string, required: true)

  defp call_code(assigns) do
    ~H"""
    <div class="lp-call-code" phx-hook="CopyToClipboard" id={"#{@id}-wrapper"}>
      <LocalizePlaygroundWeb.HexDocs.code code={@code} id={@id} />
      <button type="button" class="lp-copy-btn" data-copy-target={"##{@id}"} aria-label={gettext("Copy")}>
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <rect x="4" y="4" width="9" height="9" rx="1.5" />
          <path d="M10.5 4V2.5A1.5 1.5 0 0 0 9 1H3.5A1.5 1.5 0 0 0 2 2.5V8a1.5 1.5 0 0 0 1.5 1.5H4" />
        </svg>
        <span class="lp-copy-label">{gettext("Copy")}</span>
      </button>
    </div>
    """
  end

  attr(:result, :any, required: true)

  defp result_card(%{result: {:ok, string}} = assigns) do
    assigns = assign(assigns, :text, string)
    ~H|<div class="lp-result">{@text}</div>|
  end

  defp result_card(%{result: {:error, msg}} = assigns) do
    assigns = assign(assigns, :msg, msg)
    ~H|<div class="lp-error"><strong>{gettext("Error:")}</strong> {@msg}</div>|
  end

  defp result_card(assigns), do: ~H|<div class="lp-result lp-muted">—</div>|

  attr(:pattern, :any, required: true)

  defp pattern_card(assigns) do
    ~H"""
    <dl class="lp-meta-table lp-unit-summary">
      <dt>{gettext("Start")}</dt>
      <dd><code>{show_pattern_slot(@pattern, :start)}</code></dd>
      <dt>{gettext("Middle")}</dt>
      <dd><code>{show_pattern_slot(@pattern, :middle)}</code></dd>
      <dt>{gettext("End")}</dt>
      <dd><code>{show_pattern_slot(@pattern, :end)}</code></dd>
      <dt>{gettext("Two (special)")}</dt>
      <dd><code>{show_pattern_slot(@pattern, :two)}</code></dd>
    </dl>
    """
  end

  defp show_pattern_slot(pattern, slot) do
    case pattern do
      %{^slot => %{before: b, between: be, after: a}} ->
        "#{b}{0}#{be}{1}#{a}"

      %{^slot => value} when is_binary(value) ->
        value

      %{} ->
        map = Map.get(pattern, slot) || %{}
        inspect(map)

      _ ->
        "—"
    end
  end
end
