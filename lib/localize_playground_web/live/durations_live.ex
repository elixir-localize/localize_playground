defmodule LocalizePlaygroundWeb.DurationsLive do
  @moduledoc "Duration formatting (elapsed time, not a point or a range)."

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.DateTimeView
  alias LocalizePlaygroundWeb.NumberView

  @modes [
    %{id: :parts, label: gettext_noop("From parts"), hint: gettext_noop("Years, months, days, hours, minutes, seconds")},
    %{id: :between, label: gettext_noop("Between two dates"), hint: gettext_noop("Elapsed time between two moments")},
    %{id: :seconds, label: gettext_noop("From seconds"), hint: gettext_noop("A raw duration in seconds")}
  ]

  @format_kinds [
    %{id: :named, label: gettext_noop("Named units"), hint: gettext_noop("\"2 hours, 30 minutes\" — honours style")},
    %{id: :time, label: gettext_noop("Time pattern"), hint: gettext_noop("\"02:30:00\" — numeric clock-style")}
  ]

  @parts ~w(year month day hour minute second)a

  @impl true
  def mount(params, _session, socket) do
    locale =
      case Map.get(params, "locale") do
        nil -> "en"
        "" -> "en"
        other -> other
      end

    part_values = Map.new(@parts, fn p -> {p, default_part(p)} end)

    socket =
      socket
      |> assign(:modes, @modes)
      |> assign(:format_kinds, @format_kinds)
      |> assign(:parts, @parts)
      |> assign(:locale, locale)
      |> assign(:current_locale, locale)
      |> assign(:mode, :parts)
      |> assign(:format_kind, :named)
      |> assign(:style, :long)
      |> assign(:styles, DateTimeView.duration_styles())
      |> assign(:part_values, part_values)
      |> assign(:from_datetime, "2024-01-01T00:00:00")
      |> assign(:to_datetime, "2024-12-31T00:00:00")
      |> assign(:seconds, "9045")
      |> assign(:pattern, "hh:mm:ss")
      |> assign(:locale_options, NumberView.locale_options())
      |> compute()

    {:ok, socket}
  end

  defp default_part(:hour), do: "2"
  defp default_part(:minute), do: "30"
  defp default_part(_), do: "0"

  @impl true
  def handle_event("update", params, socket) do
    socket =
      socket
      |> apply_strings(params, ["locale", "from_datetime", "to_datetime", "seconds", "pattern"])
      |> apply_atoms(params, ["mode", "format_kind", "style"])
      |> apply_parts(params)
      |> assign(:current_locale, if(params["locale"] in [nil, ""], do: socket.assigns.current_locale, else: params["locale"]))
      |> compute()

    {:noreply, socket}
  end

  defp apply_strings(socket, params, keys) do
    Enum.reduce(keys, socket, fn key, acc ->
      case Map.get(params, key) do
        nil -> acc
        value -> assign(acc, String.to_atom(key), value)
      end
    end)
  end

  defp apply_atoms(socket, params, keys) do
    Enum.reduce(keys, socket, fn key, acc ->
      case Map.get(params, key) do
        nil -> acc
        "" -> acc
        value ->
          try do
            assign(acc, String.to_atom(key), String.to_existing_atom(value))
          rescue
            ArgumentError -> acc
          end
      end
    end)
  end

  defp apply_parts(socket, params) do
    updated =
      Enum.reduce(@parts, socket.assigns.part_values, fn part, acc ->
        case Map.get(params, "part_#{part}") do
          nil -> acc
          value -> Map.put(acc, part, value)
        end
      end)

    assign(socket, :part_values, updated)
  end

  defp compute(socket) do
    {duration, parse_error} = build_duration(socket.assigns)

    result =
      cond do
        parse_error ->
          {:error, parse_error}

        socket.assigns.format_kind == :named ->
          DateTimeView.format_duration(duration, locale: socket.assigns.locale, style: socket.assigns.style)

        socket.assigns.format_kind == :time ->
          DateTimeView.format_duration_time(duration, socket.assigns.pattern)
      end

    socket
    |> assign(:result, result)
    |> assign(:duration, duration)
    |> assign(:call_code, build_call_code(socket.assigns, duration))
  end

  defp build_duration(%{mode: :parts, part_values: parts}) do
    integers =
      Enum.reduce_while(parts, %{}, fn {k, v}, acc ->
        case parse_int(v) do
          {:ok, n} -> {:cont, Map.put(acc, k, n)}
          :error -> {:halt, {:error, "Invalid number for #{k}"}}
        end
      end)

    case integers do
      {:error, msg} ->
        {nil, msg}

      %{} = map ->
        {struct(Localize.Duration, Map.to_list(map)), nil}
    end
  end

  defp build_duration(%{mode: :between, from_datetime: a, to_datetime: b}) do
    with {:ok, d1} <- NaiveDateTime.from_iso8601(a),
         {:ok, d2} <- NaiveDateTime.from_iso8601(b),
         dt1 = DateTime.from_naive!(d1, "Etc/UTC"),
         dt2 = DateTime.from_naive!(d2, "Etc/UTC"),
         {:ok, duration} <- DateTimeView.duration_between(dt1, dt2) do
      {duration, nil}
    else
      _ -> {nil, "Invalid date/time in range"}
    end
  end

  defp build_duration(%{mode: :seconds, seconds: text}) do
    case parse_int(text) do
      {:ok, n} -> {Localize.Duration.new_from_seconds(n), nil}
      :error -> {nil, "Invalid seconds"}
    end
  end

  defp parse_int(nil), do: :error
  defp parse_int(""), do: {:ok, 0}

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_int(n) when is_integer(n), do: {:ok, n}

  defp build_call_code(_assigns, nil), do: "# fill in the duration"

  defp build_call_code(assigns, duration) do
    duration_literal = format_duration_literal(duration)

    case assigns.format_kind do
      :named ->
        opts = [locale: inspect(assigns.locale), style: inspect(assigns.style)]
        kv = opts |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)

        "duration = #{duration_literal}\nLocalize.Duration.to_string(duration, #{kv})"

      :time ->
        "duration = #{duration_literal}\nLocalize.Duration.to_time_string(duration, format: #{inspect(assigns.pattern)})"
    end
  end

  # Renders the duration as an Elixir %Duration{} struct literal,
  # omitting zero-valued fields for clarity.
  defp format_duration_literal(%Localize.Duration{} = d) do
    fields =
      [
        {:year, d.year},
        {:month, d.month},
        {:day, d.day},
        {:hour, d.hour},
        {:minute, d.minute},
        {:second, d.second}
      ]
      |> Enum.reject(fn {_k, v} -> v == 0 end)

    case fields do
      [] ->
        "%Duration{second: 0}"

      parts ->
        kv = parts |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
        "%Duration{#{kv}}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title={gettext("Locale")}>
        <div class="lp-dt-top">
          <.field label={gettext("Locale")} for="locale">
            <input id="locale" name="locale" type="text" list="dr-locales" value={@locale} phx-debounce="200" />
            <datalist id="dr-locales">
              <option :for={l <- @locale_options} value={l}></option>
            </datalist>
          </.field>
        </div>
      </.section>

      <.section title={gettext("Input mode")}>
        <div class="lp-radio-cards">
          <label :for={m <- @modes} class={"lp-radio-card" <> if(@mode == m.id, do: " active", else: "")}>
            <input type="radio" name="mode" value={m.id} checked={@mode == m.id} />
            <span class="lp-radio-title">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", m.label)}</span>
            <span class="lp-radio-hint">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", m.hint)}</span>
          </label>
        </div>

        <div class="lp-dt-format-controls">
          <%= case @mode do %>
            <% :parts -> %>
              <.field :for={p <- @parts} label={Phoenix.Naming.humanize(p)}>
                <input name={"part_#{p}"} type="number" value={Map.get(@part_values, p)} phx-debounce="250" min="0" />
              </.field>
            <% :between -> %>
              <.field label={gettext("From (ISO 8601)")} for="from_datetime">
                <input id="from_datetime" name="from_datetime" type="text" value={@from_datetime} phx-debounce="250" />
              </.field>
              <.field label={gettext("To (ISO 8601)")} for="to_datetime">
                <input id="to_datetime" name="to_datetime" type="text" value={@to_datetime} phx-debounce="250" />
              </.field>
            <% :seconds -> %>
              <.field label={gettext("Seconds")} for="seconds">
                <input id="seconds" name="seconds" type="number" value={@seconds} phx-debounce="250" min="0" />
              </.field>
          <% end %>
        </div>
      </.section>

      <.section title={gettext("Formatted duration")} class="lp-result-section">
        <.call_code code={@call_code} />
        <.result_card result={@result} />
      </.section>

      <.section title={gettext("Format")}>
        <div class="lp-radio-cards">
          <label :for={k <- @format_kinds} class={"lp-radio-card" <> if(@format_kind == k.id, do: " active", else: "")}>
            <input type="radio" name="format_kind" value={k.id} checked={@format_kind == k.id} />
            <span class="lp-radio-title">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", k.label)}</span>
            <span class="lp-radio-hint">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", k.hint)}</span>
          </label>
        </div>

        <div class="lp-dt-format-controls">
          <%= case @format_kind do %>
            <% :named -> %>
              <.field label={gettext("Style")}>
                <select name="style">
                  <option :for={s <- @styles} value={s} selected={@style == s}>{s}</option>
                </select>
              </.field>
            <% :time -> %>
              <.field label={gettext("Pattern")} for="pattern" hint={gettext("e.g. hh:mm:ss, h:mm, mm:ss")}>
                <input id="pattern" name="pattern" type="text" value={@pattern} phx-debounce="250" class="lp-mono-input" />
              </.field>
          <% end %>
        </div>
      </.section>
    </form>
    """
  end

  attr :code, :string, required: true

  defp call_code(assigns) do
    ~H"""
    <div class="lp-call-code" phx-hook="CopyToClipboard" id="dr-call-wrapper">
      <LocalizePlaygroundWeb.HexDocs.code code={@code} id="dr-call-text" />
      <button type="button" class="lp-copy-btn" data-copy-target="#dr-call-text" aria-label={gettext("Copy")}>
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
    ~H|<div class="lp-result">{@text}</div>|
  end

  defp result_card(%{result: {:error, msg}} = assigns) do
    assigns = assign(assigns, :msg, msg)
    ~H|<div class="lp-error"><strong>{gettext("Error:")}</strong> {@msg}</div>|
  end

  defp result_card(assigns), do: ~H|<div class="lp-result lp-muted">—</div>|
end
