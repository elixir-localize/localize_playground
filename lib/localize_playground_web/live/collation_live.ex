defmodule LocalizePlaygroundWeb.CollationLive do
  @moduledoc """
  Collation playground: pick a locale, pick a collation variant, tweak
  the BCP-47 collation options, edit the word list, and watch the sorted
  output update live.
  """

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.CollationView

  @impl true
  def mount(params, _session, socket) do
    seed_locale =
      case Map.get(params, "locale") do
        nil -> "en"
        "" -> "en"
        other -> other
      end

    language = language_of(seed_locale)
    collations = CollationView.available_collations(language)
    collation = hd(collations)
    words = CollationView.seed_words(language) |> Enum.join("\n")

    option_values =
      for {key, _title, _desc, kind, _choices} <- CollationView.option_specs(),
          into: %{} do
        case kind do
          :checkbox -> {key, false}
          :select -> {key, ""}
        end
      end

    socket =
      socket
      |> assign(:locale, seed_locale)
      |> assign(:language, language)
      |> assign(:collations, collations)
      |> assign(:collation, collation)
      |> assign(:words_text, words)
      |> assign(:options, option_values)
      |> assign(:option_specs, CollationView.option_specs())
      |> assign(:current_locale, seed_locale)
      |> compute()

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    previous_locale = socket.assigns.locale
    locale = Map.get(params, "locale", socket.assigns.locale) |> String.trim()
    language = language_of(locale)

    collations =
      if language != socket.assigns.language,
        do: CollationView.available_collations(language),
        else: socket.assigns.collations

    collation =
      case Map.get(params, "collation") do
        nil ->
          socket.assigns.collation

        value ->
          try do
            String.to_existing_atom(value)
          rescue
            ArgumentError -> socket.assigns.collation
          end
      end

    collation = if collation in collations, do: collation, else: hd(collations)

    words_text = Map.get(params, "words", socket.assigns.words_text)

    options =
      Enum.reduce(socket.assigns.option_specs, socket.assigns.options, fn
        {key, _, _, :checkbox, _}, acc ->
          checked? = Map.has_key?(params, "opt_#{key}")
          Map.put(acc, key, checked?)

        {key, _, _, :select, _}, acc ->
          case Map.get(params, "opt_#{key}") do
            nil -> acc
            value -> Map.put(acc, key, value)
          end
      end)

    words_text =
      if language != socket.assigns.language do
        CollationView.seed_words(language) |> Enum.join("\n")
      else
        words_text
      end

    socket =
      socket
      |> assign(:locale, locale)
      |> assign(:language, language)
      |> assign(:collations, collations)
      |> assign(:collation, collation)
      |> assign(:words_text, words_text)
      |> assign(:options, options)
      |> assign(:current_locale, if(locale == "", do: "en", else: locale))
      |> compute()

    _ = previous_locale
    {:noreply, socket}
  end

  defp language_of(locale) when is_binary(locale) do
    locale |> String.split("-") |> hd() |> String.downcase()
  end

  defp compute(socket) do
    words = parse_words(socket.assigns.words_text)

    full_options =
      CollationView.build_options(
        socket.assigns.locale,
        socket.assigns.collation,
        socket.assigns.options
      )

    {result, error} =
      case CollationView.sort(words, full_options) do
        {:ok, sorted} -> {sorted, nil}
        {:error, message} -> {words, message}
      end

    socket
    |> assign(:words, words)
    |> assign(:sorted, result)
    |> assign(:call_opts, format_call_opts(full_options))
    |> assign(:error, error)
  end

  defp parse_words(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp format_call_opts(options) do
    options |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title="Locale & collation">
        <div class="lp-coll-header">
          <.field label="Locale" for="locale" hint="Any BCP-47 locale string. Extra -u- options below will override.">
            <input
              id="locale"
              name="locale"
              type="text"
              value={@locale}
              phx-debounce="200"
            />
          </.field>
          <.field label="Collation variant" for="collation" hint="Variants available for this language.">
            <select id="collation" name="collation">
              <option :for={variant <- @collations} value={variant} selected={@collation == variant}>
                {humanize(variant)}
              </option>
            </select>
          </.field>
        </div>
      </.section>

      <.section title="Sorted result" class="lp-result-section">
        <.call_code_card opts_text={@call_opts} />
        <.sorted_card sorted={@sorted} error={@error} />
      </.section>

      <.section title="Collation options">
        <p class="lp-muted lp-helper">
          Each option here is applied on top of the locale's built-in tailoring. Leave a select on its default to let the locale decide.
        </p>
        <div class="lp-coll-options">
          <div :for={{key, title, description, kind, choices} <- @option_specs} class="lp-coll-option">
            <div class="lp-coll-option-label">
              <strong>{title}</strong>
              <span class="lp-coll-option-desc">{description}</span>
            </div>
            <div class="lp-coll-option-control">
              <.opt_input key={key} kind={kind} choices={choices} value={Map.get(@options, key)} />
            </div>
          </div>
        </div>
      </.section>

      <.section title="Word list">
        <p class="lp-muted lp-helper">
          One word per line. Changing the language swaps in a fresh seed list; your edits are kept otherwise.
        </p>
        <textarea
          id="word-list"
          name="words"
          rows="10"
          class="lp-coll-words"
          phx-debounce="250"
          spellcheck="false"
        >{@words_text}</textarea>
      </.section>
    </form>
    """
  end

  attr :key, :atom, required: true
  attr :kind, :atom, required: true
  attr :choices, :any, required: true
  attr :value, :any, required: true

  defp opt_input(%{kind: :checkbox} = assigns) do
    ~H"""
    <label class="lp-checkbox">
      <input type="checkbox" name={"opt_#{@key}"} value="true" checked={@value == true} />
      <span>Enable</span>
    </label>
    """
  end

  defp opt_input(%{kind: :select} = assigns) do
    ~H"""
    <select name={"opt_#{@key}"}>
      <option :for={{value, label} <- @choices} value={value} selected={@value == value}>
        {label}
      </option>
    </select>
    """
  end

  attr :opts_text, :string, required: true

  defp call_code_card(assigns) do
    ~H"""
    <div class="lp-call-code" phx-hook="CopyToClipboard" id="coll-call-wrapper">
      <pre class="lp-call-code-text" id="coll-call-text"><span>Localize.Collation.sort(</span><a href="#word-list" class="lp-words-link">words</a><span :if={@opts_text != ""}>, {@opts_text}</span><span>)</span></pre>
      <button
        type="button"
        class="lp-copy-btn"
        aria-label="Copy sort call to clipboard"
        data-copy-target="#coll-call-text"
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

  attr :sorted, :list, required: true
  attr :error, :any, required: true

  defp sorted_card(%{error: message} = assigns) when is_binary(message) do
    ~H"""
    <div class="lp-error">
      <strong>Collation error:</strong> {@error}
    </div>
    """
  end

  defp sorted_card(assigns) do
    ~H"""
    <ol class="lp-coll-result">
      <li :for={w <- @sorted}>{w}</li>
    </ol>
    """
  end

  defp humanize(:standard), do: "Standard"
  defp humanize(:phonebk), do: "Phonebook (phonebk)"
  defp humanize(:traditional), do: "Traditional"
  defp humanize(:pinyin), do: "Pinyin"
  defp humanize(:stroke), do: "Stroke"
  defp humanize(:zhuyin), do: "Zhuyin"
  defp humanize(:unihan), do: "Unihan"
  defp humanize(:dict), do: "Dictionary (dict)"
  defp humanize(:search), do: "Search"

  defp humanize(other) when is_atom(other) do
    other
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
