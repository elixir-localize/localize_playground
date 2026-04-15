defmodule LocalizePlaygroundWeb.IntervalsLive do
  @moduledoc "Date / DateTime interval formatting (a range between two moments)."

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.DateTimeView
  alias LocalizePlaygroundWeb.NumberView

  @families [
    %{id: :date, label: "Date interval", hint: "Apr 22–25, 2024"},
    %{id: :datetime, label: "Date & time interval", hint: "Apr 22 2024, 09:00 – Apr 25 2024, 17:00"}
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
      |> assign(:locale, locale)
      |> assign(:current_locale, locale)
      |> assign(:family, :date)
      |> assign(:format, :medium)
      |> assign(:style, :date)
      |> assign(:formats, DateTimeView.interval_formats())
      |> assign(:styles, DateTimeView.interval_styles())
      |> assign(:from_date, "2024-04-22")
      |> assign(:to_date, "2024-04-25")
      |> assign(:from_datetime, "2024-04-22T09:00:00")
      |> assign(:to_datetime, "2024-04-25T17:00:00")
      |> assign(:locale_options, NumberView.locale_options())
      |> compute()

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    socket =
      socket
      |> apply_strings(params, ["locale", "from_date", "to_date", "from_datetime", "to_datetime"])
      |> apply_atoms(params, ["family", "format", "style"])
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

  defp compute(socket) do
    {from, to, parse_error} = parse_inputs(socket.assigns)

    options = [locale: socket.assigns.locale, format: socket.assigns.format, style: socket.assigns.style]

    result =
      cond do
        parse_error -> {:error, parse_error}
        true -> DateTimeView.format_interval(from, to, options)
      end

    socket
    |> assign(:result, result)
    |> assign(:call_code, build_call_code(socket.assigns, from, to))
  end

  defp parse_inputs(%{family: :date, from_date: a, to_date: b}) do
    with {:ok, d1} <- Date.from_iso8601(a),
         {:ok, d2} <- Date.from_iso8601(b) do
      {d1, d2, nil}
    else
      _ -> {nil, nil, "Invalid date in range"}
    end
  end

  defp parse_inputs(%{family: :datetime, from_datetime: a, to_datetime: b}) do
    with {:ok, d1} <- NaiveDateTime.from_iso8601(a),
         {:ok, d2} <- NaiveDateTime.from_iso8601(b) do
      {d1, d2, nil}
    else
      _ -> {nil, nil, "Invalid date/time in range"}
    end
  end

  defp build_call_code(_assigns, nil, _), do: "# fill in both endpoints"
  defp build_call_code(_assigns, _, nil), do: "# fill in both endpoints"

  defp build_call_code(assigns, from, to) do
    opts = [
      {:locale, inspect(assigns.locale)},
      {:format, inspect(assigns.format)},
      {:style, inspect(assigns.style)}
    ]

    opts_str = opts |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
    "Localize.Interval.to_string(#{inspect(from)}, #{inspect(to)}, #{opts_str})"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title="Locale & range">
        <div class="lp-dt-top">
          <.field label="Locale" for="locale">
            <input id="locale" name="locale" type="text" list="iv-locales" value={@locale} phx-debounce="200" />
            <datalist id="iv-locales">
              <option :for={l <- @locale_options} value={l}></option>
            </datalist>
          </.field>

          <.field :if={@family == :date} label="From" for="from_date">
            <input id="from_date" name="from_date" type="text" value={@from_date} phx-debounce="250" />
          </.field>
          <.field :if={@family == :date} label="To" for="to_date">
            <input id="to_date" name="to_date" type="text" value={@to_date} phx-debounce="250" />
          </.field>

          <.field :if={@family == :datetime} label="From (ISO 8601)" for="from_datetime">
            <input id="from_datetime" name="from_datetime" type="text" value={@from_datetime} phx-debounce="250" />
          </.field>
          <.field :if={@family == :datetime} label="To (ISO 8601)" for="to_datetime">
            <input id="to_datetime" name="to_datetime" type="text" value={@to_datetime} phx-debounce="250" />
          </.field>
        </div>
      </.section>

      <.section title="Formatted interval" class="lp-result-section">
        <.call_code code={@call_code} />
        <.result_card result={@result} />
      </.section>

      <.section title="Family">
        <div class="lp-radio-cards">
          <label :for={f <- @families} class={"lp-radio-card" <> if(@family == f.id, do: " active", else: "")}>
            <input type="radio" name="family" value={f.id} checked={@family == f.id} />
            <span class="lp-radio-title">{f.label}</span>
            <span class="lp-radio-hint">{f.hint}</span>
          </label>
        </div>
      </.section>

      <.section title="Style & format">
        <div class="lp-sub-controls">
          <.field label="Format" hint="Tightness of the representation">
            <select name="format">
              <option :for={f <- @formats} value={f} selected={@format == f}>{f}</option>
            </select>
          </.field>
          <.field label="Style" hint="Which components render">
            <select name="style">
              <option :for={s <- @styles} value={s} selected={@style == s}>{s}</option>
            </select>
          </.field>
        </div>
      </.section>
    </form>
    """
  end

  attr :code, :string, required: true

  defp call_code(assigns) do
    ~H"""
    <div class="lp-call-code" phx-hook="CopyToClipboard" id="iv-call-wrapper">
      <pre class="lp-call-code-text" id="iv-call-text">{@code}</pre>
      <button type="button" class="lp-copy-btn" data-copy-target="#iv-call-text" aria-label="Copy">
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
