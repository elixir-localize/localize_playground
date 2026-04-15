defmodule LocalizePlaygroundWeb.MessagesLive do
  @moduledoc """
  Messages tab — MessageFormat 2 (MF2) playground modelled on
  <https://messageformat.unicode.org/playground/>. Users enter an MF2
  message, a set of bindings in Elixir map/keyword syntax, and see the
  formatted output for the chosen locale.
  """

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.NumberView

  @default_message ~S|.local $count = {$count :number}
.match $count
0 {{You have no unread messages.}}
1 {{You have one unread message.}}
* {{You have {$count} unread messages.}}|

  @default_bindings ~S|%{count: 3}|

  @examples [
    %{
      name: "Plural match",
      message: ~S|.local $count = {$count :number}
.match $count
0 {{You have no unread messages.}}
1 {{You have one unread message.}}
* {{You have {$count} unread messages.}}|,
      bindings: ~S|%{count: 3}|
    },
    %{
      name: "Gender select",
      message: ~S|.local $g = {$gender :string}
.match $g
feminine {{She invited you.}}
masculine {{He invited you.}}
* {{They invited you.}}|,
      bindings: ~S|%{gender: "feminine"}|
    },
    %{
      name: "Gender + plural",
      message: ~S|.local $g = {$gender :string}
.local $n = {$count :number}
.match $g $n
feminine 0   {{She didn't invite anyone.}}
feminine 1   {{She invited one guest.}}
feminine *   {{She invited {$count} guests.}}
masculine 0 {{He didn't invite anyone.}}
masculine 1 {{He invited one guest.}}
masculine * {{He invited {$count} guests.}}
*         0 {{They didn't invite anyone.}}
*         1 {{They invited one guest.}}
*         * {{They invited {$count} guests.}}|,
      bindings: ~S|%{gender: "feminine", count: 3}|
    },
    %{
      name: "Currency",
      message: ~S|{{Total: {$amount :currency currency=USD}}}|,
      bindings: ~S|%{amount: 1234.56}|
    },
    %{
      name: "Date formatting",
      message: ~S|{{Scheduled for {$when :datetime dateStyle=full timeStyle=short}}}|,
      bindings: ~S|%{when: DateTime.utc_now()}|
    },
    %{
      name: "Nested variables",
      message: ~S|.local $greeting = {Hello}
{{{$greeting}, {$name}!}}|,
      bindings: ~S|%{name: "Aoife"}|
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
      |> assign(:message, @default_message)
      |> assign(:bindings_text, @default_bindings)
      |> assign(:examples, @examples)
      |> compute()

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    socket =
      socket
      |> maybe_assign(params, "locale", :locale)
      |> maybe_assign(params, "message", :message)
      |> maybe_assign(params, "bindings_text", :bindings_text)
      |> assign(:current_locale, if(params["locale"] in [nil, ""], do: socket.assigns.current_locale, else: params["locale"]))
      |> compute()

    {:noreply, socket}
  end

  def handle_event("load_example", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    case Enum.at(@examples, index) do
      nil ->
        {:noreply, socket}

      example ->
        socket =
          socket
          |> assign(:message, example.message)
          |> assign(:bindings_text, example.bindings)
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

  defp compute(socket) do
    a = socket.assigns
    {bindings, binding_error} = parse_bindings(a.bindings_text)

    {result, parse_info} =
      case binding_error do
        nil ->
          case Localize.Message.format(a.message, bindings, locale: a.locale) do
            {:ok, string} ->
              {{:ok, string}, describe_message(a.message)}

            {:error, reason} ->
              {{:error, format_error(reason)}, describe_message(a.message)}
          end

        error ->
          {{:error, error}, nil}
      end

    socket
    |> assign(:bindings, bindings)
    |> assign(:binding_error, binding_error)
    |> assign(:result, result)
    |> assign(:parse_info, parse_info)
    |> assign(:call_code, build_call_code(a))
  end

  # Parse the bindings textarea as Elixir source. Accepts any expression
  # that evaluates to a map or keyword list. Evaluation is restricted to
  # a small env — this is a developer playground, so we accept the risk
  # of arbitrary eval but catch any raised errors.
  defp parse_bindings(text) when is_binary(text) do
    trimmed = String.trim(text)

    if trimmed == "" do
      {%{}, nil}
    else
      try do
        {value, _} = Code.eval_string(trimmed, [], __ENV__)

        cond do
          is_map(value) -> {value, nil}
          Keyword.keyword?(value) -> {value, nil}
          true -> {%{}, "Bindings must evaluate to a map or keyword list, got: #{inspect(value)}"}
        end
      rescue
        error -> {%{}, "Could not parse bindings: #{Exception.message(error)}"}
      end
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(%{__exception__: true} = exception), do: Exception.message(exception)
  defp format_error(other), do: inspect(other)

  defp describe_message(message) do
    case Localize.Message.Parser.parse(message) do
      {:ok, _ast} -> :ok
      {:error, reason} when is_binary(reason) -> {:parse_error, reason}
      {:error, reason} -> {:parse_error, inspect(reason)}
    end
  rescue
    error -> {:parse_error, Exception.message(error)}
  end

  defp build_call_code(%{bindings_text: bindings_text, locale: locale}) do
    locale_opt =
      if to_string(locale) == "en", do: "", else: ", locale: #{inspect(to_string(locale))}"

    bindings_literal =
      bindings_text
      |> String.trim()
      |> case do
        "" -> "%{}"
        text -> text
      end

    "Localize.Message.format(message, #{bindings_literal}#{locale_opt})"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title={gettext("Message")}>
        <div class="lp-dt-top">
          <.field label={gettext("Locale")} for="locale">
            <input id="locale" name="locale" type="text" list="msg-locales" value={@locale} phx-debounce="200" />
            <datalist id="msg-locales">
              <option :for={l <- @locale_options} value={l}></option>
            </datalist>
          </.field>
        </div>
      </.section>

      <.section title={gettext("Formatted output")} class="lp-result-section">
        <.result_card result={@result} />
        <.call_code code={@call_code} id="msg-call" />
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
              {example.name}
            </button>
          </div>
          <button type="button" class="lp-mf2-example-btn lp-mf2-help-btn" data-mf2-open>
            {gettext("📖 Open MF2 syntax reference")}
          </button>
        </div>
      </.section>

      <.section title={gettext("MF2 message")}>
        <.field label={gettext("MessageFormat 2 syntax")} for="message" hint={gettext("MessageFormat 2 syntax. See messageformat.unicode.org for the spec.")}>
          <textarea id="message" name="message" class="lp-mf2-message" rows="8" spellcheck="false" phx-debounce="250">{@message}</textarea>
        </.field>
      </.section>

      <.section title={gettext("Bindings")}>
        <.field label={gettext("Elixir map or keyword list")} for="bindings_text" hint={gettext("Evaluated as Elixir source. Use a map or keyword list.")}>
          <textarea id="bindings_text" name="bindings_text" class="lp-mf2-bindings" rows="4" spellcheck="false" phx-debounce="250">{@bindings_text}</textarea>
        </.field>
        <div :if={@binding_error} class="lp-error"><strong>{gettext("Binding error:")}</strong> {@binding_error}</div>
      </.section>
    </form>
    """
  end

  attr :code, :string, required: true
  attr :id, :string, required: true

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
