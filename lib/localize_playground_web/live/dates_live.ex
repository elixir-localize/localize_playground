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
    %{id: :date, label: "Date", hint: "Just the date — no time of day"},
    %{id: :time, label: "Time", hint: "Just the time — no date"},
    %{id: :datetime, label: "Date & Time", hint: "Combined, with locale join pattern"}
  ]

  @format_kinds [
    %{id: :style, label: "Standard style", hint: "short · medium · long · full"},
    %{id: :skeleton, label: "Skeleton", hint: "CLDR skeleton like yMMMd — locale picks the pattern"},
    %{id: :pattern, label: "Custom pattern", hint: "Raw CLDR pattern, e.g. yyyy-MM-dd 'at' HH:mm"}
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
      |> assign(:date_text, "2024-06-15")
      |> assign(:time_text, "14:30:00")
      |> assign(:datetime_text, "2024-06-15T14:30:00")
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
        "datetime_text"
      ])
      |> apply_atom_params(params, [
        "family",
        "format_kind",
        "style",
        "calendar",
        "prefer"
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

    {result, skeleton_info, pattern_tokens} =
      cond do
        parse_error ->
          {{:error, parse_error}, nil, nil}

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

          pattern_tokens =
            if socket.assigns.format_kind == :pattern do
              case DateTimeView.tokenize_pattern(socket.assigns.pattern) do
                {:ok, tokens} -> tokens
                _ -> nil
              end
            else
              nil
            end

          {result, skeleton_info, pattern_tokens}

        true ->
          {{:error, "Enter a value"}, nil, nil}
      end

    socket
    |> assign(:result, result)
    |> assign(:skeleton_info, skeleton_info)
    |> assign(:pattern_tokens, pattern_tokens)
    |> assign(:call_code, build_call_code(socket.assigns, input, format_display))
  end

  defp build_options(assigns, locale) do
    base = [locale: locale, prefer: assigns.prefer]

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
    case NaiveDateTime.from_iso8601(text) do
      {:ok, dt} ->
        {dt, nil}

      {:error, _} ->
        # Accept "2024-06-15T14:30" shortened form (no seconds)
        case NaiveDateTime.from_iso8601(text <> ":00") do
          {:ok, dt} -> {dt, nil}
          _ -> {nil, "Invalid date/time: #{inspect(text)}"}
        end
    end
  end

  defp do_format(:date, %Date{} = d, options), do: DateTimeView.format_date(d, options)
  defp do_format(:time, %Time{} = t, options), do: DateTimeView.format_time(t, Keyword.delete(options, :convert_to))

  defp do_format(:datetime, %NaiveDateTime{} = dt, options),
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
      <.section title="Locale & value">
        <div class="lp-dt-top">
          <.field label="Locale" for="locale" hint="Any BCP-47 locale. Shared with other tabs.">
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

          <.field label="Calendar" hint="Which CLDR calendar to format in.">
            <select name="calendar">
              <option :for={{value, label} <- @calendar_options} value={value} selected={@calendar == value}>
                {label}
              </option>
            </select>
          </.field>

          <.field :if={@family == :date} label="Date (YYYY-MM-DD)" for="date_text">
            <input id="date_text" name="date_text" type="text" value={@date_text} phx-debounce="250" />
          </.field>

          <.field :if={@family == :time} label="Time (HH:MM:SS)" for="time_text">
            <input id="time_text" name="time_text" type="text" value={@time_text} phx-debounce="250" />
          </.field>

          <.field :if={@family == :datetime} label="Date & Time (ISO 8601)" for="datetime_text">
            <input id="datetime_text" name="datetime_text" type="text" value={@datetime_text} phx-debounce="250" />
          </.field>
        </div>
      </.section>

      <.section title="Formatted output" class="lp-result-section">
        <.call_code code={@call_code} />
        <.result_card result={@result} />
      </.section>

      <.section title="What to format">
        <div class="lp-radio-cards">
          <label :for={f <- @families} class={"lp-radio-card" <> if(@family == f.id, do: " active", else: "")}>
            <input type="radio" name="family" value={f.id} checked={@family == f.id} />
            <span class="lp-radio-title">{f.label}</span>
            <span class="lp-radio-hint">{f.hint}</span>
          </label>
        </div>
      </.section>

      <.section title="Format kind">
        <div class="lp-radio-cards">
          <label :for={k <- @format_kinds} class={"lp-radio-card" <> if(@format_kind == k.id, do: " active", else: "")}>
            <input type="radio" name="format_kind" value={k.id} checked={@format_kind == k.id} />
            <span class="lp-radio-title">{k.label}</span>
            <span class="lp-radio-hint">{k.hint}</span>
          </label>
        </div>

        <div class="lp-dt-format-controls">
          <%= case @format_kind do %>
            <% :style -> %>
              <.field label="Style">
                <select name="style">
                  <option :for={s <- @standard_styles} value={s} selected={@style == s}>{s}</option>
                </select>
              </.field>
              <.field label="Prefer (time)">
                <select name="prefer">
                  <option value="unicode" selected={@prefer == :unicode}>Unicode (space-saving)</option>
                  <option value="ascii" selected={@prefer == :ascii}>ASCII-only</option>
                </select>
              </.field>
            <% :skeleton -> %>
              <.field label="Skeleton" for="skeleton" hint="e.g. yMMMd, EHm, yQQQ">
                <input id="skeleton" name="skeleton" type="text" list="skeletons" value={@skeleton} phx-debounce="200" />
                <datalist id="skeletons">
                  <option :for={s <- @skeletons} value={s}></option>
                </datalist>
              </.field>
              <.field label="Prefer (time)">
                <select name="prefer">
                  <option value="unicode" selected={@prefer == :unicode}>Unicode</option>
                  <option value="ascii" selected={@prefer == :ascii}>ASCII-only</option>
                </select>
              </.field>
            <% :pattern -> %>
              <.field label="Pattern" for="pattern" hint="CLDR pattern; quote literals with single quotes.">
                <input id="pattern" name="pattern" type="text" value={@pattern} phx-debounce="200" class="lp-mono-input" />
              </.field>
          <% end %>
        </div>
      </.section>

      <.section :if={@skeleton_info} title="Skeleton resolution">
        <.skeleton_info info={@skeleton_info} />
      </.section>

      <.section :if={@pattern_tokens} title="Pattern tokens">
        <.pattern_tokens tokens={@pattern_tokens} />
      </.section>
    </form>
    """
  end

  attr :code, :string, required: true

  defp call_code(assigns) do
    ~H"""
    <div class="lp-call-code" phx-hook="CopyToClipboard" id="dt-call-wrapper">
      <pre class="lp-call-code-text" id="dt-call-text">{@code}</pre>
      <button
        type="button"
        class="lp-copy-btn"
        aria-label="Copy"
        data-copy-target="#dt-call-text"
      >
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <rect x="4" y="4" width="9" height="9" rx="1.5" />
          <path d="M10.5 4V2.5A1.5 1.5 0 0 0 9 1H3.5A1.5 1.5 0 0 0 2 2.5V8a1.5 1.5 0 0 0 1.5 1.5H4" />
        </svg>
        <span class="lp-copy-label">Copy</span>
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
    <div class="lp-error"><strong>Error:</strong> {@text}</div>
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
      <dt>Requested skeleton</dt>
      <dd><code>{inspect(@info.requested)}</code></dd>
      <dt>Resolved skeleton</dt>
      <dd><code>{inspect(@info.resolved)}</code></dd>
      <dt>Derived pattern</dt>
      <dd><code>{inspect(@info.pattern)}</code></dd>
    </dl>
    """
  end

  attr :tokens, :list, required: true

  defp pattern_tokens(assigns) do
    ~H"""
    <table class="lp-table">
      <thead>
        <tr><th>Token</th><th>Type</th><th>Count / literal</th></tr>
      </thead>
      <tbody>
        <tr :for={{{type, rest}, i} <- Enum.with_index(@tokens)}>
          <td>{i + 1}</td>
          <td><code>{type}</code></td>
          <td><code>{inspect(rest)}</code></td>
        </tr>
      </tbody>
    </table>
    """
  end
end
