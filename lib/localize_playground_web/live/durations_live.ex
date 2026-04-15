defmodule LocalizePlaygroundWeb.DurationsLive do
  @moduledoc "Duration formatting (elapsed time, not a point or a range)."

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.DateTimeView
  alias LocalizePlaygroundWeb.NumberView

  @modes [
    %{id: :parts, label: "From parts", hint: "Years, months, days, hours, minutes, seconds"},
    %{id: :between, label: "Between two dates", hint: "Elapsed time between two moments"},
    %{id: :seconds, label: "From seconds", hint: "A raw duration in seconds"}
  ]

  @format_kinds [
    %{id: :named, label: "Named units", hint: "\"2 hours, 30 minutes\" — honours style"},
    %{id: :time, label: "Time pattern", hint: "\"02:30:00\" — numeric clock-style"}
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
    base =
      case assigns.format_kind do
        :named ->
          opts = [locale: inspect(assigns.locale), style: inspect(assigns.style)]
          kv = opts |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
          "Localize.Duration.to_string(#{inspect(duration)}, #{kv})"

        :time ->
          "Localize.Duration.to_time_string(#{inspect(duration)}, format: #{inspect(assigns.pattern)})"
      end

    base
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title="Locale">
        <div class="lp-dt-top">
          <.field label="Locale" for="locale">
            <input id="locale" name="locale" type="text" list="dr-locales" value={@locale} phx-debounce="200" />
            <datalist id="dr-locales">
              <option :for={l <- @locale_options} value={l}></option>
            </datalist>
          </.field>
        </div>
      </.section>

      <.section title="Input mode">
        <div class="lp-radio-cards">
          <label :for={m <- @modes} class={"lp-radio-card" <> if(@mode == m.id, do: " active", else: "")}>
            <input type="radio" name="mode" value={m.id} checked={@mode == m.id} />
            <span class="lp-radio-title">{m.label}</span>
            <span class="lp-radio-hint">{m.hint}</span>
          </label>
        </div>

        <div class="lp-dt-format-controls">
          <%= case @mode do %>
            <% :parts -> %>
              <.field :for={p <- @parts} label={Phoenix.Naming.humanize(p)}>
                <input name={"part_#{p}"} type="number" value={Map.get(@part_values, p)} phx-debounce="250" min="0" />
              </.field>
            <% :between -> %>
              <.field label="From (ISO 8601)" for="from_datetime">
                <input id="from_datetime" name="from_datetime" type="text" value={@from_datetime} phx-debounce="250" />
              </.field>
              <.field label="To (ISO 8601)" for="to_datetime">
                <input id="to_datetime" name="to_datetime" type="text" value={@to_datetime} phx-debounce="250" />
              </.field>
            <% :seconds -> %>
              <.field label="Seconds" for="seconds">
                <input id="seconds" name="seconds" type="number" value={@seconds} phx-debounce="250" min="0" />
              </.field>
          <% end %>
        </div>
      </.section>

      <.section title="Formatted duration" class="lp-result-section">
        <.call_code code={@call_code} />
        <.result_card result={@result} />
      </.section>

      <.section title="Format">
        <div class="lp-radio-cards">
          <label :for={k <- @format_kinds} class={"lp-radio-card" <> if(@format_kind == k.id, do: " active", else: "")}>
            <input type="radio" name="format_kind" value={k.id} checked={@format_kind == k.id} />
            <span class="lp-radio-title">{k.label}</span>
            <span class="lp-radio-hint">{k.hint}</span>
          </label>
        </div>

        <div class="lp-dt-format-controls">
          <%= case @format_kind do %>
            <% :named -> %>
              <.field label="Style">
                <select name="style">
                  <option :for={s <- @styles} value={s} selected={@style == s}>{s}</option>
                </select>
              </.field>
            <% :time -> %>
              <.field label="Pattern" for="pattern" hint="e.g. hh:mm:ss, h:mm, mm:ss">
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
      <pre class="lp-call-code-text" id="dr-call-text">{@code}</pre>
      <button type="button" class="lp-copy-btn" data-copy-target="#dr-call-text" aria-label="Copy">
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
    ~H|<div class="lp-result">{@text}</div>|
  end

  defp result_card(%{result: {:error, msg}} = assigns) do
    assigns = assign(assigns, :msg, msg)
    ~H|<div class="lp-error"><strong>Error:</strong> {@msg}</div>|
  end

  defp result_card(assigns), do: ~H|<div class="lp-result lp-muted">—</div>|
end
