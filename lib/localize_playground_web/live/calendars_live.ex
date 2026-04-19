defmodule LocalizePlaygroundWeb.CalendarsLive do
  @moduledoc """
  Calendars tab — showcases `Localize.Calendar.display_name/3` and the
  CLDR week/territory metadata. Designed to help a new developer see how
  CLDR exposes months, days, quarters, eras, and day periods across
  calendar systems, widths (wide/abbreviated/narrow/short), and contexts
  (format vs. stand-alone).
  """

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.NumberView

  @styles [
    {:wide, gettext_noop("wide — e.g. \"January\"")},
    {:abbreviated, gettext_noop("abbreviated — e.g. \"Jan\"")},
    {:narrow, gettext_noop("narrow — e.g. \"J\"")},
    {:short, gettext_noop("short — day names only (Su/Mo)")}
  ]

  @contexts [
    {:format, gettext_noop("format — used inside a date (\"on Monday\")")},
    {:stand_alone, gettext_noop("stand_alone — standalone capitalisation (\"Monday\")")}
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
      |> assign(:calendar, :gregorian)
      |> assign(:calendars, Localize.Calendar.known_calendars() |> Enum.sort())
      |> assign(:style, :wide)
      |> assign(:styles, @styles)
      |> assign(:context, :format)
      |> assign(:contexts, @contexts)
      |> refresh()

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    socket =
      socket
      |> maybe_assign(params, "locale", :locale)
      |> apply_atoms(params, ["calendar", "style", "context"])
      |> assign(
        :current_locale,
        if(params["locale"] in [nil, ""],
          do: socket.assigns.current_locale,
          else: params["locale"]
        )
      )
      |> refresh()

    {:noreply, socket}
  end

  defp maybe_assign(socket, params, key, assign_key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) -> assign(socket, assign_key, value)
      _ -> socket
    end
  end

  defp apply_atoms(socket, params, keys) do
    Enum.reduce(keys, socket, fn key, acc ->
      case Map.get(params, key) do
        nil ->
          acc

        "" ->
          acc

        value ->
          try do
            assign(acc, String.to_atom(key), String.to_existing_atom(value))
          rescue
            ArgumentError -> acc
          end
      end
    end)
  end

  defp refresh(socket) do
    a = socket.assigns
    locale = a.locale
    calendar = a.calendar
    style = a.style
    context = a.context

    socket
    |> assign(:calendar_name, lookup(:calendar, calendar, locale, style, context, calendar))
    |> assign(:calendar_call_code, build_calendar_call_code(calendar, locale, style, context))
    |> assign(:months, fetch_range(1..13, :month, locale, style, context, calendar))
    |> assign(:days, fetch_range(1..7, :day, locale, style, context, calendar))
    |> assign(:quarters, fetch_range(1..4, :quarter, locale, style, context, calendar))
    |> assign(:eras, fetch_eras(locale, style, context, calendar))
    |> assign(:day_periods, fetch_day_periods(locale, style, context, calendar))
    |> assign(:date_time_fields, fetch_date_time_fields(locale, style, context, calendar))
    |> assign(:week_info, week_info(locale))
  end

  defp lookup(type, value, locale, style, context, calendar) do
    options = [locale: locale, style: style, context: context, calendar: calendar]

    case Localize.Calendar.display_name(type, value, options) do
      {:ok, name} -> name
      _ -> "—"
    end
  end

  defp fetch_range(range, type, locale, style, context, calendar) do
    Enum.map(range, fn n -> {n, lookup(type, n, locale, style, context, calendar)} end)
    |> Enum.reject(fn {_n, name} -> name == "—" end)
  end

  defp fetch_eras(locale, style, context, calendar) do
    # Eras are calendar-specific; try the first few indices.
    Enum.flat_map(0..4, fn n ->
      options = [locale: locale, style: style, context: context, calendar: calendar]

      case Localize.Calendar.display_name(:era, n, options) do
        {:ok, name} -> [{n, name}]
        _ -> []
      end
    end)
  end

  defp fetch_day_periods(locale, style, context, calendar) do
    periods = [
      :am,
      :pm,
      :noon,
      :midnight,
      :morning1,
      :morning2,
      :afternoon1,
      :afternoon2,
      :evening1,
      :evening2,
      :night1,
      :night2
    ]

    Enum.flat_map(periods, fn p ->
      options = [locale: locale, style: style, context: context, calendar: calendar]

      case Localize.Calendar.display_name(:day_period, p, options) do
        {:ok, name} -> [{p, name}]
        _ -> []
      end
    end)
  end

  defp fetch_date_time_fields(locale, style, _context, calendar) do
    fields = [
      :era,
      :year,
      :quarter,
      :month,
      :week,
      :weekday,
      :day,
      :day_period,
      :hour,
      :minute,
      :second,
      :zone
    ]

    Enum.flat_map(fields, fn field ->
      options = [locale: locale, style: style, calendar: calendar]

      case Localize.Calendar.display_name(:date_time_field, field, options) do
        {:ok, name} -> [{field, name}]
        _ -> []
      end
    end)
  end

  defp week_info(locale) do
    with {:ok, tag} <- Localize.LanguageTag.canonicalize(locale) do
      territory = tag.territory || :"001"

      %{
        territory: territory,
        first_day: safe_first_day(territory),
        min_days: Localize.Calendar.min_days_for_territory(territory),
        weekend: Localize.Calendar.weekend(territory),
        weekdays: Localize.Calendar.weekdays(territory)
      }
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp build_calendar_call_code(calendar, locale, style, context) do
    opts =
      [locale: inspect(to_string(locale))]
      |> maybe_add(:style, style, :wide)
      |> maybe_add(:context, context, :format)
      |> maybe_add(:calendar, calendar, :gregorian)

    options_str =
      case opts do
        [] -> ""
        list -> ", " <> Enum.map_join(list, ", ", fn {k, v} -> "#{k}: #{v}" end)
      end

    "Localize.Calendar.display_name(:calendar, #{inspect(calendar)}#{options_str})"
  end

  defp maybe_add(opts, _key, value, value), do: opts

  defp maybe_add(opts, key, value, _default) when is_atom(value),
    do: opts ++ [{key, inspect(value)}]

  defp maybe_add(opts, key, value, _default), do: opts ++ [{key, inspect(value)}]

  defp safe_first_day(territory) do
    case Localize.Calendar.first_day_for_territory(territory) do
      n when is_integer(n) -> n
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title={gettext("Locale & calendar")}>
        <div class="lp-dt-top">
          <.field label={gettext("Locale")} for="locale">
            <input id="locale" name="locale" type="text" list="cal-locales" value={@locale} phx-debounce="200" />
            <datalist id="cal-locales">
              <option :for={l <- @locale_options} value={l}></option>
            </datalist>
          </.field>

          <.field label={gettext("Calendar")} for="calendar" hint={gettext("Try :japanese, :hebrew, :islamic, :buddhist, :ethiopic…")}>
            <select id="calendar" name="calendar">
              <option :for={c <- @calendars} value={c} selected={@calendar == c}>{c}</option>
            </select>
          </.field>

          <.field label={gettext("Style / width")} for="style">
            <select id="style" name="style">
              <option :for={{id, label} <- @styles} value={id} selected={@style == id}>
                {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", label)}
              </option>
            </select>
          </.field>

          <.field label={gettext("Context")} for="context" hint={gettext("Affects capitalisation + choice of variant.")}>
            <select id="context" name="context">
              <option :for={{id, label} <- @contexts} value={id} selected={@context == id}>
                {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", label)}
              </option>
            </select>
          </.field>
        </div>
      </.section>

      <.section title={gettext("Calendar system")} class="lp-result-section">
        <p class="lp-muted lp-help-text">
          {gettext("The localized display name of the calendar system itself — derived from CLDR via Localize.Calendar.display_name/3.")}
        </p>
        <div class="lp-result">{@calendar_name}</div>
        <.call_code code={@calendar_call_code} id="cal-call" />
      </.section>

      <.section title={gettext("Months")}>
        <p class="lp-muted lp-help-text">
          {gettext("Month numbers are 1-based. Some calendars (e.g. Hebrew) have 13 months.")}
        </p>
        <.name_table rows={@months} label={gettext("Month")} />
      </.section>

      <.section title={gettext("Days of week")}>
        <p class="lp-muted lp-help-text">
          {gettext("ISO 8601 day numbers: 1 = Monday through 7 = Sunday. The first day varies by locale — see the Week info panel below.")}
        </p>
        <.name_table rows={@days} label={gettext("Day")} />
      </.section>

      <.section title={gettext("Quarters")}>
        <.name_table rows={@quarters} label={gettext("Quarter")} />
      </.section>

      <.section :if={@eras != []} title={gettext("Eras")}>
        <p class="lp-muted lp-help-text">
          {gettext("Each calendar defines its own era sequence. E.g., :japanese has Meiji, Taisho, Shōwa, Heisei, Reiwa; :gregorian has BC / AD.")}
        </p>
        <.name_table rows={@eras} label={gettext("Era")} />
      </.section>

      <.section :if={@day_periods != []} title={gettext("Day periods")}>
        <p class="lp-muted lp-help-text">
          {gettext("AM/PM plus CLDR's flexible day-period set: :morning1, :afternoon1, :evening1, :night1, etc. Not every locale defines every period.")}
        </p>
        <.name_table rows={@day_periods} label={gettext("Period")} />
      </.section>

      <.section :if={@date_time_fields != []} title={gettext("Date-time field names")}>
        <p class="lp-muted lp-help-text">
          {gettext("Localized labels for the individual fields — useful for form captions, error messages, and chrono-aware UIs.")}
        </p>
        <.name_table rows={@date_time_fields} label={gettext("Field")} />
      </.section>

      <.section :if={@week_info} title={gettext("Week info for the locale's territory")}>
        <p class="lp-muted lp-help-text">
          {gettext("CLDR tracks per-territory week conventions: which day starts the week, how many days the first week of the year must contain, and which days are weekend.")}
        </p>
        <dl class="lp-meta-table lp-unit-summary">
          <dt>{gettext("Territory")}</dt>
          <dd><code>{@week_info.territory}</code></dd>
          <dt>{gettext("First day of week")}</dt>
          <dd>{day_label(@week_info.first_day)}</dd>
          <dt>{gettext("Minimum days in first week")}</dt>
          <dd>{@week_info.min_days}</dd>
          <dt>{gettext("Weekend")}</dt>
          <dd>{@week_info.weekend |> Enum.map_join(", ", &day_label/1)}</dd>
          <dt>{gettext("Weekdays")}</dt>
          <dd>{@week_info.weekdays |> Enum.map_join(", ", &day_label/1)}</dd>
        </dl>
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

  defp day_label(nil), do: "—"
  defp day_label(1), do: "Mon (1)"
  defp day_label(2), do: "Tue (2)"
  defp day_label(3), do: "Wed (3)"
  defp day_label(4), do: "Thu (4)"
  defp day_label(5), do: "Fri (5)"
  defp day_label(6), do: "Sat (6)"
  defp day_label(7), do: "Sun (7)"
  defp day_label(n), do: to_string(n)

  attr(:rows, :list, required: true)
  attr(:label, :string, required: true)

  defp name_table(assigns) do
    ~H"""
    <table class="lp-pattern-table lp-cal-table">
      <thead>
        <tr><th>{@label}</th><th>{gettext("Value")}</th><th>{gettext("Localized name")}</th></tr>
      </thead>
      <tbody>
        <tr :for={{value, name} <- @rows}>
          <td>{format_index(value)}</td>
          <td><code>{inspect(value)}</code></td>
          <td>{name}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp format_index(n) when is_integer(n), do: n
  defp format_index(a) when is_atom(a), do: to_string(a)
  defp format_index(other), do: inspect(other)
end
