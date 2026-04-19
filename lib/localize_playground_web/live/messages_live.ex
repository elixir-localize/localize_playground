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
          # The message textarea is `phx-update="ignore"` so LiveView
          # won't replace its value on its own. Push an event instead
          # so the MF2Editor hook can set `.value` directly.
          |> push_event("mf2:set_message", %{value: example.message})

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

    # Run the message through tree-sitter first — microseconds, and
    # error-recovering. If the CST has ERROR or MISSING nodes the
    # message is mid-edit and the NimbleParsec formatter would just
    # raise noisy parse errors for every keystroke. Skip it until
    # the tree is clean and let the inline squiggles carry the UX.
    parse_clean? = not mf2_has_parse_errors?(a.message)

    result =
      cond do
        binding_error != nil ->
          {:error, binding_error}

        not parse_clean? ->
          :waiting

        true ->
          case Localize.Message.format(a.message, bindings, locale: a.locale) do
            {:ok, string} -> {:ok, string}
            {:error, reason} -> {:error, format_error(reason)}
          end
      end

    socket
    |> maybe_push_canonical(a.message, parse_clean?)
    |> assign(:bindings, bindings)
    |> assign(:binding_error, binding_error)
    |> assign(:result, result)
    |> assign(:call_code, build_call_code(a))
    |> assign_new(:message_html, fn ->
      # Server-render the highlight *once* at mount. Subsequent keystrokes
      # are handled entirely in the browser by the MF2Editor hook — the
      # <pre> carries `phx-update="ignore"` so LiveView never overwrites
      # the client's work. This initial render avoids a flash of unstyled
      # text while the WASM runtime boots.
      #
      # Localize.Message.to_html/2 emits the same tree-sitter capture
      # class names (.mf2-variable, .mf2-punctuation-bracket, …) that
      # the WASM editor paints with, so the theme stylesheet covers
      # both cleanly. The initial @message is always a known-good
      # canonical message, so the ParseError branch is defensive only.
      case Localize.Message.to_html(a.message) do
        {:ok, html} -> html
        {:error, _} -> Phoenix.HTML.html_escape(a.message) |> Phoenix.HTML.safe_to_string()
      end
    end)
  end

  # When the user's message parses cleanly, send its canonical form
  # back so the editor can snap to it on blur. The client hook holds
  # the value as a "pending" apply while the textarea has focus and
  # applies it when focus leaves, so typing is never interrupted.
  #
  # Only fire when the canonical form actually differs from the
  # current input — otherwise we'd wake the hook on every keystroke
  # to no effect.
  defp maybe_push_canonical(socket, _message, false), do: socket

  defp maybe_push_canonical(socket, message, true) do
    case Localize.Message.canonical_message(message, trim: false) do
      {:ok, canonical} when canonical != message ->
        push_event(socket, "mf2:canonical", %{value: canonical})

      _ ->
        socket
    end
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

  # True if the message fails to parse. Used to gate the formatter so
  # we don't display transient parse errors on every keystroke mid-edit.
  #
  # This is a NimbleParsec parse (abort on first error) — good enough
  # for a yes/no "is this parseable?" check. For richer diagnostics
  # the client-side tree-sitter parse in the MF2Editor hook is the
  # authoritative source; see the `mf2-diagnostics` CustomEvent.
  defp mf2_has_parse_errors?(message) do
    case Localize.Message.Parser.parse(message) do
      {:ok, _ast} -> false
      {:error, _} -> true
    end
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

      <.section title={gettext("Message and bindings")}>
        <p class="lp-field-hint">
          {gettext("MessageFormat 2 syntax — see messageformat.unicode.org for the spec. Bindings are Elixir source; use a map or keyword list.")}
        </p>
        <div class="lp-mf2-workspace">
          <div class="lp-mf2-workspace-left">
            <div
              class="lp-mf2-editor"
              phx-hook="MF2Editor"
              id="mf2-editor"
              aria-label={gettext("MessageFormat 2 source")}
            >
              <pre class="lp-mf2-highlight mf2-highlight" aria-hidden="true" phx-update="ignore" id="mf2-editor-pre"><code>{raw(@message_html)}</code></pre>
              <textarea
                id="message"
                name="message"
                class="lp-mf2-message"
                spellcheck="false"
                phx-debounce="100"
                phx-update="ignore"
                aria-label={gettext("MessageFormat 2 source")}
              >{@message}</textarea>
            </div>
            <textarea
              id="bindings_text"
              name="bindings_text"
              class="lp-mf2-bindings"
              spellcheck="false"
              phx-debounce="250"
              aria-label={gettext("Bindings (Elixir map or keyword list)")}
              placeholder="%{count: 3}"
            >{@bindings_text}</textarea>
            <div :if={@binding_error} class="lp-error"><strong>{gettext("Binding error:")}</strong> {@binding_error}</div>
          </div>
          <.mf2_shortcuts />
        </div>
      </.section>
    </form>
    """
  end

  # Keyboard-shortcut reference card shown next to the MF2 editor.
  # Mirrors the bindings documented in `mf2_wasm_editor`'s README so
  # devs and translators have a quick lookup without leaving the page.
  defp mf2_shortcuts(assigns) do
    ~H"""
    <aside class="lp-mf2-shortcuts" aria-label={gettext("MF2 editor keyboard shortcuts")}>
      <h4>{gettext("Navigation")}</h4>
      <dl>
        <dt><kbd>F12</kbd></dt>
        <dd>{gettext("Go to definition of")} <code>$var</code></dd>

        <dt><kbd>⌘</kbd>/<kbd>Ctrl</kbd>+<kbd>click</kbd></dt>
        <dd>{gettext("Same, with the mouse")}</dd>

        <dt><kbd>⌘</kbd>/<kbd>Ctrl</kbd>+<kbd>⇧</kbd>+<kbd>O</kbd></dt>
        <dd>{gettext("Outline: jump to any")} <code>.input</code> / <code>.local</code></dd>

        <dt><kbd>⌘</kbd>/<kbd>Ctrl</kbd>+<kbd>⇧</kbd>+<kbd>→</kbd></dt>
        <dd>{gettext("Grow selection to enclosing node")}</dd>

        <dt><kbd>⌘</kbd>/<kbd>Ctrl</kbd>+<kbd>⇧</kbd>+<kbd>←</kbd></dt>
        <dd>{gettext("Shrink selection")}</dd>
      </dl>

      <h4>{gettext("Refactoring")}</h4>
      <dl>
        <dt><kbd>F2</kbd></dt>
        <dd>{gettext("Rename variable in scope")}</dd>
      </dl>

      <h4>{gettext("Completion")}</h4>
      <dl>
        <dt><kbd>$</kbd></dt>
        <dd>{gettext("In-scope variables")}</dd>

        <dt><kbd>:</kbd></dt>
        <dd>{gettext("Built-in functions")}</dd>

        <dt><kbd>@</kbd></dt>
        <dd>{gettext("Attributes")}</dd>

        <dt><kbd>↑</kbd><kbd>↓</kbd> <kbd>⏎</kbd>/<kbd>⇥</kbd> <kbd>⎋</kbd></dt>
        <dd>{gettext("Navigate, accept, dismiss")}</dd>
      </dl>

      <h4>{gettext("Smart typing")}</h4>
      <dl>
        <dt><kbd>&lbrace;</kbd> / <kbd>|</kbd></dt>
        <dd>{gettext("Auto-close to brackets and pipes")}</dd>

        <dt><kbd>⏎</kbd></dt>
        <dd>{gettext("Smart indent in patterns and matchers")}</dd>

        <dt><kbd>⇥</kbd></dt>
        <dd>{gettext("Expand matcher skeleton with CLDR plurals")}</dd>
      </dl>
    </aside>
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

  defp result_card(%{result: :waiting} = assigns) do
    ~H|<div class="lp-result lp-muted">{gettext("Waiting for valid MF2…")}</div>|
  end

  defp result_card(assigns), do: ~H|<div class="lp-result lp-muted">—</div>|
end
