defmodule LocalizePlaygroundWeb.LocalesLive do
  @moduledoc """
  Locale builder tab. Users pick a language, script, and territory; apply
  any of the BCP-47 `-u-` extensions; and see the resulting canonical
  locale string. That locale propagates to the other tabs via the URL.
  """

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.LocaleView

  @impl true
  def mount(params, _session, socket) do
    seed =
      case Map.get(params, "locale") do
        nil -> "en"
        "" -> "en"
        other -> other
      end

    socket =
      socket
      |> assign(:languages, LocaleView.languages())
      |> assign(:all_scripts, LocaleView.scripts())
      |> assign(:all_territories, LocaleView.territories())
      |> assign(:u_extensions, LocaleView.u_extensions())
      |> assign(:collation_extensions, LocaleView.collation_extensions())
      |> seed_from_locale(seed)
      |> compute()

    {:ok, socket}
  end

  defp build_value_options(territory, ui_locale) do
    context = %{territory: territory, ui_locale: ui_locale}

    LocaleView.all_u_extensions()
    |> Map.new(fn {key, _title, _desc} ->
      {key, LocaleView.u_extension_values(key, context)}
    end)
  end

  defp seed_from_locale(socket, raw) do
    case Localize.validate_locale(raw) do
      {:ok, %Localize.LanguageTag{} = tag} ->
        u = tag.locale || %{}

        extensions =
          LocaleView.all_u_extensions()
          |> Map.new(fn {key, _, _} ->
            value = Map.get(u, key)
            {key, if(is_nil(value), do: "", else: to_string(value))}
          end)

        socket
        |> assign(:language, to_string(tag.language || "en"))
        |> assign(:script, to_string(tag.script || ""))
        |> assign(:territory, to_string(tag.territory || ""))
        |> assign(:extensions, extensions)

      _ ->
        default_extensions =
          LocaleView.all_u_extensions()
          |> Map.new(fn {key, _, _} -> {key, ""} end)

        socket
        |> assign(:language, "en")
        |> assign(:script, "")
        |> assign(:territory, "")
        |> assign(:extensions, default_extensions)
    end
  end

  @impl true
  def handle_event("update", params, socket) do
    previous_language = socket.assigns.language
    previous_territory = socket.assigns.territory
    language = Map.get(params, "language", socket.assigns.language) |> clean_subtag()
    script = Map.get(params, "script", socket.assigns.script) |> clean_subtag()
    territory = Map.get(params, "territory", socket.assigns.territory) |> clean_subtag()

    {script, territory} =
      if language != previous_language do
        {scripts, territories} = LocaleView.scripts_and_territories_for_language(language)
        {reset_if_invalid(script, scripts), reset_if_invalid(territory, territories)}
      else
        {script, territory}
      end

    existing = socket.assigns.extensions

    territory_changed? = territory != previous_territory

    extensions =
      Enum.reduce(existing, %{}, fn {key, current}, acc ->
        new_value =
          case Map.get(params, "ext_#{key}") do
            nil -> current
            value -> String.trim(value)
          end

        # Subdivision codes are scoped to a territory; clear the stale
        # value whenever the territory changes.
        new_value = if key == :sd and territory_changed?, do: "", else: new_value

        Map.put(acc, key, new_value)
      end)

    socket =
      socket
      |> assign(:language, language)
      |> assign(:script, script)
      |> assign(:territory, territory)
      |> assign(:extensions, extensions)
      |> compute()

    {:noreply, socket}
  end

  defp clean_subtag(nil), do: ""
  defp clean_subtag(value), do: String.trim(value)

  defp reset_if_invalid("", _), do: ""
  defp reset_if_invalid(value, []), do: value
  defp reset_if_invalid(value, allowed), do: if(value in allowed, do: value, else: "")

  defp compute(socket) do
    %{language: lang, script: script, territory: territory, extensions: extensions} =
      socket.assigns

    {scripts_for_lang, territories_for_lang} =
      LocaleView.scripts_and_territories_for_language(lang)

    raw = LocaleView.assemble_locale_string(lang, nilify(script), nilify(territory), extensions)

    {canonical, error} =
      case LocaleView.build(lang, nilify(script), nilify(territory), extensions) do
        {:ok, canonical, _tag, _raw} -> {canonical, nil}
        {:error, message} -> {raw, message}
      end

    ui_locale = Map.get(socket.assigns, :ui_locale, "en")

    {standard_name, dialect_name} =
      if error, do: {nil, nil}, else: resolve_display_names(canonical, ui_locale)

    socket
    |> assign(:scripts_for_lang, scripts_for_lang)
    |> assign(:territories_for_lang, territories_for_lang)
    |> assign(:raw_locale, raw)
    |> assign(:canonical_locale, canonical)
    |> assign(:current_locale, canonical)
    |> assign(:display_name_standard, standard_name)
    |> assign(:display_name_dialect, dialect_name)
    |> assign(:u_value_options, build_value_options(nilify(territory), Map.get(socket.assigns, :ui_locale)))
    |> assign(:error, error)
  end

  # Returns `{standard, dialect}` where each is either `{:ok, name}` or
  # `{:error, message}`, and `dialect` is `nil` when identical to
  # standard (no point displaying the same string twice).
  defp resolve_display_names(canonical, ui_locale) do
    standard = safe_display_name(canonical, locale: ui_locale)
    dialect = safe_display_name(canonical, locale: ui_locale, language_display: :dialect)

    dialect_different? =
      case {standard, dialect} do
        {{:ok, a}, {:ok, b}} -> a != b
        _ -> true
      end

    {standard, if(dialect_different?, do: dialect, else: nil)}
  end

  defp safe_display_name(canonical, options) do
    Localize.Locale.LocaleDisplay.display_name(canonical, options)
    |> case do
      {:ok, name} -> {:ok, name}
      {:error, exception} when is_exception(exception) -> {:error, Exception.message(exception)}
      other -> {:error, inspect(other)}
    end
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp nilify(""), do: nil
  defp nilify(value), do: value

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title={gettext("Language, script, territory")}>
        <div class="lp-lst-row">
          <.field label={gettext("Language")} for="language" hint={gettext("e.g. en, zh, ar")}>
            <input
              id="language"
              name="language"
              type="text"
              list="languages"
              value={@language}
              phx-debounce="150"
            />
            <datalist id="languages">
              <option :for={lang <- @languages} value={lang}></option>
            </datalist>
          </.field>

          <.field label={gettext("Script")} for="script" hint={if @scripts_for_lang == [], do: gettext("Any ISO-15924 script"), else: gettext("Known for this language")}>
            <select id="script" name="script">
              <option value="">{gettext("(unspecified)")}</option>
              <optgroup :if={@scripts_for_lang != []} label={gettext("For this language")}>
                <option :for={s <- @scripts_for_lang} value={s} selected={@script == s}>{s}</option>
              </optgroup>
              <optgroup label={gettext("All scripts")}>
                <option :for={s <- @all_scripts} value={s} selected={@script == s}>{s}</option>
              </optgroup>
            </select>
          </.field>

          <.field label={gettext("Territory")} for="territory" hint={if @territories_for_lang == [], do: gettext("Any ISO-3166 territory"), else: gettext("Known for this language")}>
            <select id="territory" name="territory">
              <option value="">{gettext("(unspecified)")}</option>
              <optgroup :if={@territories_for_lang != []} label={gettext("For this language")}>
                <option :for={t <- @territories_for_lang} value={t} selected={@territory == t}>{t}</option>
              </optgroup>
              <optgroup label={gettext("All territories")}>
                <option :for={t <- @all_territories} value={t} selected={@territory == t}>{t}</option>
              </optgroup>
            </select>
          </.field>
        </div>
      </.section>

      <.section title={gettext("Canonical locale")} class="lp-canonical-section">
        <div :if={@raw_locale != @canonical_locale and !@error} class="lp-muted lp-helper lp-canon-hint">
          {raw(gettext("You entered {$raw}; it canonicalized to {$canonical}.", raw: "<code>#{@raw_locale}</code>", canonical: "<code>#{@canonical_locale}</code>"))}
        </div>
        <.canonical_card
          canonical={@canonical_locale}
          raw={@raw_locale}
          error={@error}
          ui_locale={@ui_locale}
          display_name_standard={@display_name_standard}
          display_name_dialect={@display_name_dialect}
        />
      </.section>

      <.section title={gettext("Unicode -u extensions")}>
        <p class="lp-muted lp-helper">
          {raw(gettext("Each extension adds a {$segment} segment to the locale. Leave a field blank to omit it.", segment: "<code>-u-KEY-VALUE</code>"))}
        </p>
        <.ext_group
          extensions={@u_extensions}
          values={@extensions}
          options={@u_value_options}
          ui_locale={@ui_locale}
        />
      </.section>

      <.section title={gettext("Unicode -u collation extensions")}>
        <p class="lp-muted lp-helper">
          {raw(gettext("Collation-specific knobs that tune string sorting. These share the {$namespace} namespace with the fields above.", namespace: "<code>-u-</code>"))}
        </p>
        <.ext_group
          extensions={@collation_extensions}
          values={@extensions}
          options={@u_value_options}
          ui_locale={@ui_locale}
        />
      </.section>
    </form>
    """
  end

  attr :extensions, :list, required: true
  attr :values, :map, required: true
  attr :options, :map, required: true
  attr :ui_locale, :string, default: "en"

  defp ext_group(assigns) do
    ~H"""
    <div class="lp-ext-grid">
      <div :for={{key, title, description} <- @extensions} class="lp-ext-row">
        <div class="lp-ext-label">
          <div class="lp-ext-title">
            <strong>{LocaleView.localized_title(key, @ui_locale, Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", title))}</strong>
            <code>-u-{key}</code>
          </div>
          <span class="lp-ext-desc">{Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", description)}</span>
        </div>
        <div class="lp-ext-control">
          <.ext_input
            key={key}
            value={Map.get(@values, key, "")}
            options={Map.get(@options, key, [])}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :key, :atom, required: true
  attr :value, :string, required: true
  attr :options, :list, required: true

  defp ext_input(%{options: []} = assigns) do
    ~H"""
    <input
      name={"ext_#{@key}"}
      type="text"
      value={@value}
      placeholder="(default)"
      phx-debounce="200"
    />
    """
  end

  defp ext_input(assigns) do
    ~H"""
    <select name={"ext_#{@key}"}>
      <option value="">(default)</option>
      <option :for={{value, label} <- @options} value={value} selected={@value == value}>
        {label}
      </option>
    </select>
    """
  end

  attr :canonical, :string, required: true
  attr :raw, :string, required: true
  attr :error, :any, required: true
  attr :display_name_standard, :any, default: nil
  attr :display_name_dialect, :any, default: nil
  attr :ui_locale, :string, default: "en"

  defp canonical_card(assigns) do
    ~H"""
    <div class="lp-canonical-wrapper">
      <div class="lp-canonical" phx-hook="CopyToClipboard" id="canonical-wrapper">
        <pre class="lp-canonical-text" id="canonical-text">{@canonical}</pre>
        <button
          type="button"
          class="lp-copy-btn"
          aria-label="Copy canonical locale to clipboard"
          data-copy-target="#canonical-text"
        >
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <rect x="4" y="4" width="9" height="9" rx="1.5" />
            <path d="M10.5 4V2.5A1.5 1.5 0 0 0 9 1H3.5A1.5 1.5 0 0 0 2 2.5V8a1.5 1.5 0 0 0 1.5 1.5H4" />
          </svg>
          <span class="lp-copy-label">{gettext("Copy")}</span>
        </button>
      </div>

      <.display_name_row
        :if={@display_name_standard}
        canonical={@canonical}
        result={@display_name_standard}
        options={[locale: @ui_locale]}
      />
      <.display_name_row
        :if={@display_name_dialect}
        canonical={@canonical}
        result={@display_name_dialect}
        options={[locale: @ui_locale, language_display: :dialect]}
      />

      <div :if={@error} class="lp-error">
        <strong>{gettext("Not a valid locale yet:")}</strong> {@error}
      </div>
    </div>
    """
  end

  attr :canonical, :string, required: true
  attr :result, :any, required: true
  attr :options, :list, default: []

  defp display_name_row(assigns) do
    assigns = assign(assigns, :code, build_display_name_code(assigns.canonical, assigns.options))
    ~H"""
    <div class="lp-display-name">
      <code class="lp-display-name-code">{@code}</code>
      <div class={"lp-display-name-value" <> display_name_error_class(@result)}>
        {display_name_text(@result)}
      </div>
    </div>
    """
  end

  defp build_display_name_code(canonical, []),
    do: "Localize.Locale.LocaleDisplay.display_name(#{inspect(canonical)})"

  defp build_display_name_code(canonical, options) do
    kv = options |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)
    "Localize.Locale.LocaleDisplay.display_name(#{inspect(canonical)}, #{kv})"
  end

  defp display_name_text({:ok, name}), do: name
  defp display_name_text({:error, message}), do: "error: " <> message

  defp display_name_error_class({:ok, _}), do: ""
  defp display_name_error_class(_), do: " lp-display-name-error"
end
