defmodule LocalizePlaygroundWeb.DatesLive do
  @moduledoc """
  Dates & Times tab. Handles point-in-time formatting: Date, Time, and
  DateTime families, each with three format kinds (standard style,
  CLDR skeleton, custom pattern). Skeleton lookups show the resolved
  skeleton and the pattern that produced the output; pattern input
  shows a token breakdown.
  """

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.DateTimeView
  alias LocalizePlaygroundWeb.NumberView

  @families [
    %{id: :date, label: gettext_noop("Date"), hint: gettext_noop("Just the date — no time of day")},
    %{id: :time, label: gettext_noop("Time"), hint: gettext_noop("Just the time — no date")},
    %{id: :datetime, label: gettext_noop("Date & Time"), hint: gettext_noop("Combined, with locale join pattern")}
  ]

  @format_kinds [
    %{id: :style, label: gettext_noop("Standard format"), hint: gettext_noop("short · medium · long · full")},
    %{id: :skeleton, label: gettext_noop("Locale skeletons"), hint: gettext_noop("CLDR skeleton like yMMMd — locale picks the pattern")},
    %{id: :pattern, label: gettext_noop("Custom pattern"), hint: gettext_noop("Raw CLDR pattern, e.g. yyyy-MM-dd 'at' HH:mm")}
  ]

  @hour_cycles [
    {:auto, gettext_noop("Locale default")},
    {:h12, gettext_noop("12-hour (h12) — 1–12")},
    {:h23, gettext_noop("24-hour (h23) — 0–23")},
    {:h11, gettext_noop("12-hour (h11) — 0–11")},
    {:h24, gettext_noop("24-hour (h24) — 1–24")}
  ]

  # Common IANA timezones presented in the zone select for the datetime
  # family. The empty first option means "no shift" — keep whatever zone
  # the parsed DateTime already has.
  @common_timezones [
    "",
    "Etc/UTC",
    "America/Los_Angeles",
    "America/Denver",
    "America/Chicago",
    "America/New_York",
    "America/Sao_Paulo",
    "America/Mexico_City",
    "Europe/London",
    "Europe/Paris",
    "Europe/Berlin",
    "Europe/Madrid",
    "Europe/Moscow",
    "Africa/Cairo",
    "Africa/Johannesburg",
    "Asia/Jerusalem",
    "Asia/Dubai",
    "Asia/Kolkata",
    "Asia/Bangkok",
    "Asia/Singapore",
    "Asia/Hong_Kong",
    "Asia/Shanghai",
    "Asia/Tokyo",
    "Asia/Seoul",
    "Australia/Sydney",
    "Pacific/Auckland"
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
      |> assign(:families, @families)
      |> assign(:format_kinds, @format_kinds)
      |> assign(:standard_styles, DateTimeView.standard_styles())
      |> assign(:calendar_options, DateTimeView.calendar_options())
      |> assign(:locale_options, NumberView.locale_options())
      |> assign(:locale, locale)
      |> assign(:current_locale, locale)
      |> assign(:family, :datetime)
      |> assign(:format_kind, :style)
      |> assign(:style, :medium)
      |> assign(:skeleton, "yMMMd")
      |> assign(:pattern, "yyyy-MM-dd HH:mm")
      |> assign(:calendar, :gregorian)
      |> assign(:prefer, :unicode)
      |> assign(:hour_cycle, :auto)
      |> assign(:hour_cycles, @hour_cycles)
      |> assign(:common_timezones, @common_timezones)
      |> assign(:timezone, "")
      |> assign(:date_text, Date.to_iso8601(Date.utc_today()))
      |> assign(:time_text, Time.utc_now() |> Time.truncate(:second) |> Time.to_iso8601())
      |> assign(:datetime_text, DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601())
      |> assign(:skeletons, DateTimeView.available_skeletons(locale))
      |> compute()

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    previous_locale = socket.assigns.locale
    previous_calendar = socket.assigns.calendar

    socket =
      socket
      |> apply_string_params(params, [
        "locale",
        "skeleton",
        "pattern",
        "date_text",
        "time_text",
        "datetime_text",
        "timezone"
      ])
      |> apply_atom_params(params, [
        "family",
        "format_kind",
        "style",
        "calendar",
        "prefer",
        "hour_cycle"
      ])

    socket =
      if socket.assigns.locale != previous_locale or socket.assigns.calendar != previous_calendar do
        assign(
          socket,
          :skeletons,
          DateTimeView.available_skeletons(socket.assigns.locale, socket.assigns.calendar)
        )
      else
        socket
      end

    socket =
      socket
      |> assign(:current_locale, if(socket.assigns.locale == "", do: "en", else: socket.assigns.locale))
      |> compute()

    {:noreply, socket}
  end

  defp apply_string_params(socket, params, keys) do
    Enum.reduce(keys, socket, fn key, acc ->
      case Map.fetch(params, key) do
        {:ok, value} when is_binary(value) -> assign(acc, String.to_atom(key), value)
        _ -> acc
      end
    end)
  end

  defp apply_atom_params(socket, params, keys) do
    Enum.reduce(keys, socket, fn key, acc ->
      case Map.fetch(params, key) do
        {:ok, value} when is_binary(value) and value != "" ->
          try do
            assign(acc, String.to_atom(key), String.to_existing_atom(value))
          rescue
            ArgumentError -> acc
          end

        _ ->
          acc
      end
    end)
  end

  defp compute(socket) do
    locale = if socket.assigns.locale == "", do: "en", else: socket.assigns.locale
    {options, format_display} = build_options(socket.assigns, locale)

    {input, parse_error} = parse_input(socket.assigns)
    {input, parse_error} = maybe_shift_zone(input, socket.assigns, parse_error)

    {result, skeleton_info} =
      cond do
        parse_error ->
          {{:error, parse_error}, nil}

        input ->
          result = do_format(socket.assigns.family, input, options)

          skeleton_info =
            if socket.assigns.format_kind == :skeleton do
              try do
                DateTimeView.resolve_skeleton(
                  skeleton_atom(socket.assigns.skeleton),
                  locale,
                  socket.assigns.calendar
                )
              rescue
                _ -> nil
              end
            else
              nil
            end

          {result, skeleton_info}

        true ->
          {{:error, "Enter a value"}, nil}
      end

    socket
    |> assign(:result, result)
    |> assign(:skeleton_info, skeleton_info)
    |> assign(:call_code, build_call_code(socket.assigns, input, format_display))
  end

  defp build_options(assigns, locale) do
    effective_locale = apply_hour_cycle(locale, assigns.hour_cycle, assigns.family)
    base = [locale: effective_locale, prefer: assigns.prefer]

    format_kv =
      case assigns.format_kind do
        :style -> [format: assigns.style]
        :skeleton -> [format: skeleton_atom(assigns.skeleton)]
        :pattern -> [format: assigns.pattern]
      end

    convert =
      case DateTimeView.calendar_module(assigns.calendar) do
        nil -> []
        mod -> [convert_to: mod]
      end

    format_display =
      case assigns.format_kind do
        :style -> {:atom, assigns.style}
        :skeleton -> {:atom, skeleton_atom(assigns.skeleton)}
        :pattern -> {:string, assigns.pattern}
      end

    {base ++ format_kv ++ convert, format_display}
  end

  # Append a `-u-hc-<cycle>` extension to the locale string when the user
  # explicitly picks a cycle. Time/DateTime families only — the :date
  # family has no hour so the setting is a no-op.
  defp apply_hour_cycle(locale, :auto, _family), do: locale
  defp apply_hour_cycle(locale, _cycle, :date), do: locale

  defp apply_hour_cycle(locale, cycle, _family)
       when cycle in [:h12, :h23, :h11, :h24] do
    locale_str = to_string(locale)

    cond do
      String.contains?(locale_str, "-u-") ->
        # Replace or append the hc subtag. Simplest: strip existing -hc-XX
        # and then append.
        stripped = Regex.replace(~r/-hc-[a-z0-9]+/, locale_str, "")
        stripped <> "-hc-#{cycle}"

      true ->
        locale_str <> "-u-hc-#{cycle}"
    end
  end

  defp apply_hour_cycle(locale, _cycle, _family), do: locale

  defp skeleton_atom(value) when is_binary(value) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> :"#{value}"
    end
  end

  defp skeleton_atom(value), do: value

  defp parse_input(%{family: :date, date_text: text}) do
    case Date.from_iso8601(text) do
      {:ok, d} -> {d, nil}
      {:error, _} -> {nil, "Invalid date: #{inspect(text)}"}
    end
  end

  defp parse_input(%{family: :time, time_text: text}) do
    case Time.from_iso8601(text) do
      {:ok, t} -> {t, nil}
      {:error, _} -> {nil, "Invalid time: #{inspect(text)}"}
    end
  end

  defp parse_input(%{family: :datetime, datetime_text: text}) do
    # Try as a zoned DateTime first (handles trailing Z or ±HH:MM offsets).
    # Fall back to NaiveDateTime when there's no offset.
    case DateTime.from_iso8601(text) do
      {:ok, dt, _offset} ->
        {dt, nil}

      {:error, _} ->
        case NaiveDateTime.from_iso8601(text) do
          {:ok, dt} ->
            {dt, nil}

          {:error, _} ->
            case NaiveDateTime.from_iso8601(text <> ":00") do
              {:ok, dt} -> {dt, nil}
              _ -> {nil, "Invalid date/time: #{inspect(text)}"}
            end
        end
    end
  end

  # When the user selects a timezone on the datetime family, shift the parsed
  # DateTime into that zone. NaiveDateTime inputs are treated as UTC so that
  # the shift produces a sensible result.
  defp maybe_shift_zone(input, _assigns, error) when error != nil, do: {input, error}
  defp maybe_shift_zone(input, %{family: :datetime, timezone: tz}, _error) when tz in [nil, ""], do: {input, nil}

  defp maybe_shift_zone(%DateTime{} = dt, %{family: :datetime, timezone: tz}, _error) do
    case DateTime.shift_zone(dt, tz) do
      {:ok, shifted} -> {shifted, nil}
      {:error, reason} -> {dt, "Cannot shift to #{tz}: #{inspect(reason)}"}
    end
  end

  defp maybe_shift_zone(%NaiveDateTime{} = ndt, %{family: :datetime, timezone: tz}, _error) do
    with {:ok, as_utc} <- DateTime.from_naive(ndt, "Etc/UTC"),
         {:ok, shifted} <- DateTime.shift_zone(as_utc, tz) do
      {shifted, nil}
    else
      {:error, reason} -> {ndt, "Cannot shift to #{tz}: #{inspect(reason)}"}
    end
  end

  defp maybe_shift_zone(input, _assigns, _error), do: {input, nil}

  defp do_format(:date, %Date{} = d, options), do: DateTimeView.format_date(d, options)
  defp do_format(:time, %Time{} = t, options), do: DateTimeView.format_time(t, Keyword.delete(options, :convert_to))

  defp do_format(:datetime, %NaiveDateTime{} = dt, options),
    do: DateTimeView.format_datetime(dt, options)

  defp do_format(:datetime, %DateTime{} = dt, options),
    do: DateTimeView.format_datetime(dt, options)

  defp do_format(_, _, _), do: {:error, "Wrong input type for the selected family"}

  defp build_call_code(_assigns, nil, _), do: "# enter a value"

  defp build_call_code(assigns, input, format_display) do
    call =
      case assigns.family do
        :date -> "Localize.Date.to_string"
        :time -> "Localize.Time.to_string"
        :datetime -> "Localize.DateTime.to_string"
      end

    input_literal = inspect(input)

    opts = collect_display_opts(assigns, format_display)

    "#{call}(#{input_literal}#{if opts == "", do: "", else: ", " <> opts})"
  end

  defp collect_display_opts(assigns, format_display) do
    kvs =
      []
      |> add_if_nondefault(:locale, assigns.locale, "en")
      |> add_format(format_display)
      |> add_if_nondefault(:prefer, assigns.prefer, :unicode)
      |> add_if_nondefault(:calendar, assigns.calendar, :gregorian)

    kvs |> Enum.reverse() |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
  end

  defp add_if_nondefault(kvs, _key, value, value), do: kvs
  defp add_if_nondefault(kvs, key, value, _default), do: [{key, inspect(value)} | kvs]

  defp add_format(kvs, {:atom, atom}), do: [{:format, inspect(atom)} | kvs]
  defp add_format(kvs, {:string, string}), do: [{:format, inspect(string)} | kvs]

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title={gettext("Locale & value")}>
        <div class="lp-dt-top">
          <.field label={gettext("Locale")} for="locale">
            <input
              id="locale"
              name="locale"
              type="text"
              list="dt-locales"
              value={@locale}
              phx-debounce="200"
            />
            <datalist id="dt-locales">
              <option :for={l <- @locale_options} value={l}></option>
            </datalist>
          </.field>

          <.field label={gettext("Calendar")} hint={gettext("Which CLDR calendar to format in.")}>
            <select name="calendar">
              <option :for={{value, label} <- @calendar_options} value={value} selected={@calendar == value}>
                {label}
              </option>
            </select>
          </.field>

          <.field :if={@family == :date} label={gettext("Date (YYYY-MM-DD)")} for="date_text">
            <input id="date_text" name="date_text" type="text" value={@date_text} phx-debounce="250" />
          </.field>

          <.field :if={@family == :time} label={gettext("Time (HH:MM:SS)")} for="time_text">
            <input id="time_text" name="time_text" type="text" value={@time_text} phx-debounce="250" />
          </.field>

          <.field :if={@family == :datetime} label={gettext("Date & Time (ISO 8601)")} for="datetime_text" hint={gettext("Add a trailing Z or ±HH:MM offset to format as a DateTime with time zone.")}>
            <input id="datetime_text" name="datetime_text" type="text" value={@datetime_text} phx-debounce="250" />
          </.field>

          <.field :if={@family == :datetime} label={gettext("Shift to time zone")} for="timezone" hint={gettext("Picks an IANA zone and calls DateTime.shift_zone/2.")}>
            <select id="timezone" name="timezone">
              <option :for={tz <- @common_timezones} value={tz} selected={@timezone == tz}>
                {if tz == "", do: gettext("(none)"), else: tz}
              </option>
            </select>
          </.field>
        </div>

        <div :if={@family in [:time, :datetime]} class="lp-dt-secondary-row">
          <.field label={gettext("Hour cycle")}>
            <select name="hour_cycle">
              <option :for={{value, label} <- @hour_cycles} value={value} selected={@hour_cycle == value}>
                {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", label)}
              </option>
            </select>
          </.field>
        </div>
      </.section>

      <.section title={gettext("Formatted output")} class="lp-result-section">
        <.call_code code={@call_code} />
        <.result_card result={@result} />
      </.section>

      <.section title={gettext("What to format")}>
        <div class="lp-radio-cards">
          <label :for={f <- @families} class={"lp-radio-card" <> if(@family == f.id, do: " active", else: "")}>
            <input type="radio" name="family" value={f.id} checked={@family == f.id} />
            <span class="lp-radio-title">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", f.label)}</span>
            <span class="lp-radio-hint">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", f.hint)}</span>
          </label>
        </div>
      </.section>

      <.section title={gettext("Format kind")}>
        <div class="lp-radio-cards">
          <label :for={k <- @format_kinds} class={"lp-radio-card" <> if(@format_kind == k.id, do: " active", else: "")}>
            <input type="radio" name="format_kind" value={k.id} checked={@format_kind == k.id} />
            <span class="lp-radio-title">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", k.label)}</span>
            <span class="lp-radio-hint">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", k.hint)}</span>
          </label>
        </div>

        <div class="lp-dt-format-controls">
          <%= case @format_kind do %>
            <% :style -> %>
              <.field label={gettext("Format")}>
                <select name="style">
                  <option :for={s <- @standard_styles} value={s} selected={@style == s}>{String.capitalize(to_string(s))}</option>
                </select>
              </.field>
              <.field label={gettext("Prefer")}>
                <select name="prefer">
                  <option value="unicode" selected={@prefer == :unicode}>{gettext("Unicode (recommended)")}</option>
                  <option value="ascii" selected={@prefer == :ascii}>{gettext("ASCII-only")}</option>
                </select>
              </.field>
            <% :skeleton -> %>
              <.field label={gettext("Skeleton")} for="skeleton" hint={gettext("All CLDR skeletons for date, time, and datetime.")}>
                <select id="skeleton" name="skeleton">
                  <option :for={s <- @skeletons} value={s} selected={to_string(@skeleton) == to_string(s)}>{s}</option>
                </select>
              </.field>
              <.field label={gettext("Prefer")}>
                <select name="prefer">
                  <option value="unicode" selected={@prefer == :unicode}>{gettext("Unicode (recommended)")}</option>
                  <option value="ascii" selected={@prefer == :ascii}>{gettext("ASCII-only")}</option>
                </select>
              </.field>
            <% :pattern -> %>
              <.field label={gettext("Pattern")} for="pattern" hint={gettext("CLDR pattern; quote literals with single quotes.")}>
                <input id="pattern" name="pattern" type="text" value={@pattern} phx-debounce="200" class="lp-mono-input" />
              </.field>
              <div class="lp-pattern-help">
                <button type="button" class="lp-pattern-help-btn" data-pattern-open>
                  {gettext("📖 Open pattern reference panel")}
                </button>
              </div>
          <% end %>
        </div>
      </.section>

      <.section :if={@skeleton_info} title={gettext("Skeleton resolution")}>
        <.skeleton_info info={@skeleton_info} />
      </.section>

    </form>
    """
  end

  attr :code, :string, required: true

  defp call_code(assigns) do
    ~H"""
    <div class="lp-call-code" phx-hook="CopyToClipboard" id="dt-call-wrapper">
      <LocalizePlaygroundWeb.HexDocs.code code={@code} id="dt-call-text" />
      <button
        type="button"
        class="lp-copy-btn"
        aria-label={gettext("Copy")}
        data-copy-target="#dt-call-text"
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

  attr :result, :any, required: true

  defp result_card(%{result: {:ok, string}} = assigns) do
    assigns = assign(assigns, :text, string)

    ~H"""
    <div class="lp-result">{@text}</div>
    """
  end

  defp result_card(%{result: {:error, message}} = assigns) do
    assigns = assign(assigns, :text, message)

    ~H"""
    <div class="lp-error"><strong>{gettext("Error:")}</strong> {@text}</div>
    """
  end

  defp result_card(assigns) do
    ~H"""
    <div class="lp-result lp-muted">—</div>
    """
  end

  attr :info, :map, required: true

  defp skeleton_info(%{info: %{error: _}} = assigns) do
    ~H"""
    <div class="lp-error">{@info.error}</div>
    """
  end

  defp skeleton_info(assigns) do
    ~H"""
    <dl class="lp-meta-table">
      <dt>{gettext("Requested skeleton")}</dt>
      <dd><code>{inspect(@info.requested)}</code></dd>
      <dt>{gettext("Resolved skeleton")}</dt>
      <dd><code>{inspect(@info.resolved)}</code></dd>
      <dt>{gettext("Derived pattern")}</dt>
      <dd><code>{inspect(@info.pattern)}</code></dd>
    </dl>
    """
  end

end
