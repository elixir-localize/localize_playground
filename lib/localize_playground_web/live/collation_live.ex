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
      |> assign(:reorder_codes, [])
      |> assign(:reorder_choices, CollationView.reorder_choices())
      |> assign(:reorder_selection, "")
      |> assign(:presets, CollationView.presets())
      |> assign(:show_keys, false)
      |> assign(:compare_a, nil)
      |> assign(:compare_b, nil)
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

    reorder_selection = Map.get(params, "reorder_selection", socket.assigns.reorder_selection)
    compare_a = Map.get(params, "compare_a", socket.assigns.compare_a)
    compare_b = Map.get(params, "compare_b", socket.assigns.compare_b)

    socket =
      socket
      |> assign(:locale, locale)
      |> assign(:language, language)
      |> assign(:collations, collations)
      |> assign(:collation, collation)
      |> assign(:words_text, words_text)
      |> assign(:options, options)
      |> assign(:reorder_selection, reorder_selection)
      |> assign(:compare_a, compare_a)
      |> assign(:compare_b, compare_b)
      |> assign(:current_locale, if(locale == "", do: "en", else: locale))
      |> compute()

    _ = previous_locale
    {:noreply, socket}
  end

  def handle_event("reorder_add", _params, socket) do
    code = socket.assigns.reorder_selection

    socket =
      if code in [nil, ""] or code in socket.assigns.reorder_codes do
        socket
      else
        socket
        |> assign(:reorder_codes, socket.assigns.reorder_codes ++ [code])
        |> assign(:reorder_selection, "")
        |> compute()
      end

    {:noreply, socket}
  end

  def handle_event("reorder_remove", %{"code" => code}, socket) do
    codes = Enum.reject(socket.assigns.reorder_codes, &(&1 == code))

    {:noreply, socket |> assign(:reorder_codes, codes) |> compute()}
  end

  def handle_event("reorder_move", %{"code" => code, "direction" => direction}, socket) do
    codes = socket.assigns.reorder_codes
    index = Enum.find_index(codes, &(&1 == code))

    new_codes =
      cond do
        is_nil(index) ->
          codes

        direction == "up" and index > 0 ->
          swap(codes, index, index - 1)

        direction == "down" and index < length(codes) - 1 ->
          swap(codes, index, index + 1)

        true ->
          codes
      end

    {:noreply, socket |> assign(:reorder_codes, new_codes) |> compute()}
  end

  def handle_event("reorder_clear", _params, socket) do
    {:noreply, socket |> assign(:reorder_codes, []) |> compute()}
  end

  def handle_event("apply_preset", %{"preset" => name}, socket) do
    preset_id =
      try do
        String.to_existing_atom(name)
      rescue
        ArgumentError -> nil
      end

    options =
      case preset_id do
        :default ->
          CollationView.default_options(socket.assigns.option_specs)

        id when is_atom(id) ->
          case CollationView.preset_options(id) do
            nil -> socket.assigns.options
            overrides -> apply_preset_overrides(socket.assigns, overrides)
          end

        _ ->
          socket.assigns.options
      end

    {:noreply, socket |> assign(:options, options) |> compute()}
  end

  def handle_event("toggle_keys", _params, socket) do
    {:noreply, socket |> assign(:show_keys, !socket.assigns.show_keys) |> compute()}
  end

  def handle_event("persist_text", %{"value" => value}, socket) do
    {:noreply, socket |> assign(:words_text, value) |> compute()}
  end

  defp apply_preset_overrides(assigns, overrides) do
    base = CollationView.default_options(assigns.option_specs)

    Enum.reduce(overrides, base, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp swap(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)

    list
    |> List.replace_at(i, b)
    |> List.replace_at(j, a)
  end

  defp language_of(locale) when is_binary(locale) do
    locale |> String.split("-") |> hd() |> String.downcase()
  end

  defp compute(socket) do
    words = parse_words(socket.assigns.words_text)

    reorder = CollationView.normalize_reorder(socket.assigns.reorder_codes || [])

    full_options =
      CollationView.build_options(
        socket.assigns.locale,
        socket.assigns.collation,
        socket.assigns.options
      )
      |> maybe_append(:reorder, reorder)

    # Baseline: the user's locale with no extra knobs. Used to show
    # which words moved relative to the locale's default behaviour.
    baseline_options = [locale: if(socket.assigns.locale == "", do: "en", else: socket.assigns.locale)]

    {result, error} =
      case CollationView.sort(words, full_options) do
        {:ok, sorted} -> {sorted, nil}
        {:error, message} -> {words, message}
      end

    baseline =
      case CollationView.sort(words, baseline_options) do
        {:ok, sorted} -> sorted
        _ -> words
      end

    diff =
      if error do
        []
      else
        build_diff(result, baseline)
      end

    sort_keys =
      if socket.assigns.show_keys and is_nil(error) do
        CollationView.sort_keys(result, full_options) |> Map.new()
      else
        %{}
      end

    {compare_a, compare_b} = seed_compare(socket.assigns, words)

    compare_result =
      if compare_a && compare_b && compare_a != "" && compare_b != "" do
        CollationView.compare(compare_a, compare_b, full_options)
      else
        nil
      end

    socket
    |> assign(:words, words)
    |> assign(:sorted, result)
    |> assign(:diff, diff)
    |> assign(:sort_keys, sort_keys)
    |> assign(:compare_a, compare_a)
    |> assign(:compare_b, compare_b)
    |> assign(:compare_result, compare_result)
    |> assign(:call_opts, format_call_opts(full_options))
    |> assign(:error, error)
  end

  # Returns a list of `{word, delta}` tuples where `delta` is an
  # integer: positive = moved later vs baseline, negative = moved
  # earlier, 0 = unchanged.
  defp build_diff(sorted, baseline) do
    baseline_index = baseline |> Enum.with_index() |> Map.new()

    sorted
    |> Enum.with_index()
    |> Enum.map(fn {word, new_index} ->
      case Map.fetch(baseline_index, word) do
        {:ok, old_index} -> {word, new_index - old_index}
        :error -> {word, 0}
      end
    end)
  end

  defp seed_compare(assigns, words) do
    a =
      cond do
        is_binary(assigns.compare_a) -> assigns.compare_a
        match?([_ | _], words) -> Enum.at(words, 0)
        true -> ""
      end

    b =
      cond do
        is_binary(assigns.compare_b) -> assigns.compare_b
        match?([_, _ | _], words) -> Enum.at(words, 1)
        true -> ""
      end

    {a, b}
  end

  defp maybe_append(opts, _key, []), do: opts
  defp maybe_append(opts, key, value), do: opts ++ [{key, value}]

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
        <div class="lp-result-toolbar">
          <button type="button" phx-click="toggle_keys" class={"lp-chip #{if @show_keys, do: "on"}"}>
            {if @show_keys, do: "Hide sort keys", else: "Show sort keys"}
          </button>
        </div>
        <.sorted_card sorted={@sorted} diff={@diff} keys={@sort_keys} error={@error} />

        <div class="lp-compare-widget">
          <div class="lp-compare-label">Pairwise compare</div>
          <div class="lp-compare-row">
            <input type="text" name="compare_a" value={@compare_a} placeholder="first word"
              phx-debounce="200" />
            <span class="lp-compare-verdict lp-compare-verdict-box">
              <.compare_verdict result={@compare_result} />
            </span>
            <input type="text" name="compare_b" value={@compare_b} placeholder="second word"
              phx-debounce="200" />
          </div>
        </div>
      </.section>

      <.section title="Quick presets">
        <p class="lp-muted lp-helper">
          One-click combinations of the options below. They replace any current overrides.
        </p>
        <div class="lp-preset-chips">
          <button :for={{id, label, desc, _opts} <- @presets}
            type="button"
            class="lp-preset-chip"
            phx-click="apply_preset"
            phx-value-preset={id}
            title={desc}
          >{label}</button>
        </div>
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

      <.section title="Reorder codes (-u-kr)">
        <p class="lp-muted lp-helper">
          Reorder groups of scripts relative to each other. Earlier entries sort first; anything not listed keeps its default position. Example: add <code>Cyrl</code> then <code>Latn</code> to make Cyrillic sort before Latin.
        </p>

        <div class="lp-reorder-picker">
          <select name="reorder_selection">
            <option value="">Pick a script or group…</option>
            <option
              :for={{value, label} <- @reorder_choices}
              value={value}
              disabled={value in @reorder_codes}
              selected={@reorder_selection == value}
            >
              {label}
            </option>
          </select>
          <button type="button" phx-click="reorder_add" class="lp-secondary-btn" disabled={@reorder_selection in ["", nil]}>
            Add
          </button>
          <button :if={@reorder_codes != []} type="button" phx-click="reorder_clear" class="lp-ghost-btn">
            Clear all
          </button>
        </div>

        <ol :if={@reorder_codes != []} class="lp-reorder-list">
          <li :for={{code, index} <- Enum.with_index(@reorder_codes)} class="lp-reorder-chip">
            <span class="lp-reorder-pos">{index + 1}.</span>
            <code class="lp-reorder-code">{code}</code>
            <div class="lp-reorder-actions">
              <button
                type="button"
                phx-click="reorder_move"
                phx-value-code={code}
                phx-value-direction="up"
                disabled={index == 0}
                aria-label="Move up"
              >▲</button>
              <button
                type="button"
                phx-click="reorder_move"
                phx-value-code={code}
                phx-value-direction="down"
                disabled={index == length(@reorder_codes) - 1}
                aria-label="Move down"
              >▼</button>
              <button
                type="button"
                phx-click="reorder_remove"
                phx-value-code={code}
                aria-label="Remove"
                class="lp-reorder-remove"
              >✕</button>
            </div>
          </li>
        </ol>
      </.section>

      <.section title="Word list">
        <p :if={caption = CollationView.seed_caption(@language)} class="lp-seed-caption">
          💡 {caption}
        </p>
        <p class="lp-muted lp-helper">
          One word per line. Changing the language swaps in a fresh seed list; your edits are kept otherwise.
        </p>
        <textarea
          id="word-list"
          name="words"
          rows="10"
          class="lp-coll-words"
          phx-debounce="250"
          phx-update="replace"
          phx-hook="PersistText"
          data-storage-key={"lp-collation-words-" <> @language}
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
  attr :diff, :list, default: []
  attr :keys, :map, default: %{}
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
      <li :for={{word, delta} <- @diff}>
        <span class="lp-word">{word}</span>
        <span class={"lp-delta lp-delta-#{delta_class(delta)}"}>{delta_label(delta)}</span>
        <span :if={Map.has_key?(@keys, word)} class="lp-sort-key">{Map.get(@keys, word)}</span>
      </li>
    </ol>
    """
  end

  defp delta_class(0), do: "none"
  defp delta_class(d) when d < 0, do: "up"
  defp delta_class(_), do: "down"

  defp delta_label(0), do: "—"
  defp delta_label(d) when d < 0, do: "▲ #{-d}"
  defp delta_label(d), do: "▼ #{d}"

  attr :result, :any, required: true

  defp compare_verdict(%{result: :lt} = assigns),
    do: ~H|<span class="lp-verdict lp-verdict-lt">&lt;</span>|

  defp compare_verdict(%{result: :eq} = assigns),
    do: ~H|<span class="lp-verdict lp-verdict-eq">=</span>|

  defp compare_verdict(%{result: :gt} = assigns),
    do: ~H|<span class="lp-verdict lp-verdict-gt">&gt;</span>|

  defp compare_verdict(%{result: {:error, _}} = assigns),
    do: ~H|<span class="lp-verdict lp-verdict-err">!</span>|

  defp compare_verdict(assigns), do: ~H|<span class="lp-verdict">?</span>|

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
