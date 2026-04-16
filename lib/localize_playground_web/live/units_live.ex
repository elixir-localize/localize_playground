defmodule LocalizePlaygroundWeb.UnitsLive do
  @moduledoc "Units tab: compose a CLDR unit, format it, and convert."

  use LocalizePlaygroundWeb, :live_view

  alias LocalizePlaygroundWeb.UnitView
  alias LocalizePlaygroundWeb.NumberView

  # Human-readable labels for SI prefixes. Extracted at compile time
  # via `gettext_noop/1` and translated at render time.
  @prefix_labels %{
    none: gettext_noop("(none)"),
    yocto: gettext_noop("yocto (10⁻²⁴)"),
    zepto: gettext_noop("zepto (10⁻²¹)"),
    atto: gettext_noop("atto (10⁻¹⁸)"),
    femto: gettext_noop("femto (10⁻¹⁵)"),
    pico: gettext_noop("pico (10⁻¹²)"),
    nano: gettext_noop("nano (10⁻⁹)"),
    micro: gettext_noop("micro (10⁻⁶)"),
    milli: gettext_noop("milli (10⁻³)"),
    centi: gettext_noop("centi (10⁻²)"),
    deci: gettext_noop("deci (10⁻¹)"),
    deka: gettext_noop("deka (10¹)"),
    hecto: gettext_noop("hecto (10²)"),
    kilo: gettext_noop("kilo (10³)"),
    mega: gettext_noop("mega (10⁶)"),
    giga: gettext_noop("giga (10⁹)"),
    tera: gettext_noop("tera (10¹²)"),
    peta: gettext_noop("peta (10¹⁵)"),
    exa: gettext_noop("exa (10¹⁸)"),
    zetta: gettext_noop("zetta (10²¹)"),
    yotta: gettext_noop("yotta (10²⁴)")
  }

  @power_labels %{
    none: gettext_noop("(none)"),
    square: gettext_noop("square (x²)"),
    cubic: gettext_noop("cubic (x³)"),
    pow4: gettext_noop("pow4 (x⁴)"),
    pow5: gettext_noop("pow5 (x⁵)"),
    pow6: gettext_noop("pow6 (x⁶)"),
    pow7: gettext_noop("pow7 (x⁷)"),
    pow8: gettext_noop("pow8 (x⁸)"),
    pow9: gettext_noop("pow9 (x⁹)")
  }

  @systems [
    {:metric, gettext_noop("Metric (SI)")},
    {:us, gettext_noop("US customary")},
    {:uk, gettext_noop("UK imperial")}
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
      |> assign(:prefixes, UnitView.si_prefixes())
      |> assign(:powers, UnitView.powers())
      |> assign(:prefix_labels, @prefix_labels)
      |> assign(:power_labels, @power_labels)
      |> assign(:units_by_category, UnitView.units_by_category())
      |> assign(:systems, @systems)
      |> assign(:number, "42")
      |> assign(:source_power, :none)
      |> assign(:source_prefix, :kilo)
      |> assign(:source_category, "length")
      |> assign(:source_unit, "meter")
      |> assign(:target_power, :none)
      |> assign(:target_prefix, :none)
      |> assign(:target_category, "length")
      |> assign(:target_unit, "mile")
      |> assign(:system, :us)
      |> compute()

    {:ok, socket}
  end

  @impl true
  def handle_event("update", params, socket) do
    socket =
      socket
      |> apply_strings(params, ["locale", "number"])
      |> apply_atoms(params, ["source_power", "source_prefix", "target_power", "target_prefix", "system"])
      |> apply_category_and_unit(params, :source)
      |> apply_category_and_unit(params, :target)
      |> assign(:current_locale, if(params["locale"] in [nil, ""], do: socket.assigns.current_locale, else: params["locale"]))
      |> compute()

    {:noreply, socket}
  end

  # When the user picks a new category, reset the unit to the first member of
  # that category. When they pick a new unit within the same category, just
  # update the unit. Keeps the two selects in sync.
  defp apply_category_and_unit(socket, params, which) do
    cat_key = "#{which}_category"
    unit_key = "#{which}_unit"
    current_cat = Map.get(socket.assigns, String.to_atom(cat_key))

    new_cat =
      case Map.get(params, cat_key) do
        nil -> current_cat
        "" -> current_cat
        value -> value
      end

    socket = assign(socket, String.to_atom(cat_key), new_cat)

    if new_cat != current_cat do
      # Category changed: snap the unit to the first one in the new category.
      units_for_new = units_for_category(socket.assigns.units_by_category, new_cat)
      assign(socket, String.to_atom(unit_key), List.first(units_for_new) || "")
    else
      # Category unchanged: honour any submitted unit that belongs to the category.
      submitted = Map.get(params, unit_key)
      units_for_cat = units_for_category(socket.assigns.units_by_category, new_cat)

      cond do
        submitted in [nil, ""] -> socket
        submitted in units_for_cat -> assign(socket, String.to_atom(unit_key), submitted)
        true -> socket
      end
    end
  end

  defp units_for_category(units_by_category, cat) do
    case List.keyfind(units_by_category, cat, 0) do
      {_, units} -> units
      _ -> []
    end
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
    a = socket.assigns
    locale = a.locale

    source_name = UnitView.compose_unit(a.source_power, a.source_prefix, a.source_unit)
    target_name = UnitView.compose_unit(a.target_power, a.target_prefix, a.target_unit)

    {source_result, source_unit_struct, source_call_code} =
      case UnitView.parse_number(a.number) do
        {:error, message} ->
          {{:error, message}, nil, build_new_code(a.number, source_name)}

        {:ok, value} ->
          case UnitView.build_and_format(value, source_name, locale) do
            {:ok, %{unit: unit} = info} ->
              {{:ok, info}, unit, build_to_string_code(value, source_name, locale)}

            {:error, message} ->
              {{:error, message}, nil, build_new_code(value, source_name)}
          end
      end

    conversion_result =
      case source_unit_struct do
        nil ->
          nil

        unit ->
          UnitView.convert(unit, target_name, locale)
      end

    conversion_code = build_convert_code(source_name, target_name, locale)

    preferred_result =
      case source_unit_struct do
        nil ->
          nil

        unit ->
          UnitView.convert_measurement_system(unit, a.system, locale)
      end

    preferred_code = build_preferred_code(source_name, a.system, locale)

    territory_system = territory_system_for_locale(locale)

    territory_result =
      case source_unit_struct do
        nil ->
          nil

        unit ->
          UnitView.convert_measurement_system(unit, territory_system, locale)
      end

    territory_code = build_territory_system_code(source_name, locale)

    socket
    |> assign(:source_unit_name, source_name)
    |> assign(:target_unit_name, target_name)
    |> assign(:source_result, source_result)
    |> assign(:source_call_code, source_call_code)
    |> assign(:unit_name_code, build_unit_name_code(source_name))
    |> assign(:display_name_code, build_display_name_code(source_name, locale))
    |> assign(:category_code, build_category_code(source_name))
    |> assign(:conversion_result, conversion_result)
    |> assign(:conversion_call_code, conversion_code)
    |> assign(:preferred_result, preferred_result)
    |> assign(:preferred_call_code, preferred_code)
    |> assign(:territory_result, territory_result)
    |> assign(:territory_call_code, territory_code)
    |> assign(:territory_system, territory_system)
  end

  defp territory_system_for_locale(locale) do
    with {:ok, tag} <- Localize.LanguageTag.canonicalize(locale),
         territory when not is_nil(territory) <- tag.territory do
      Localize.Unit.measurement_system_for_territory(territory)
    else
      _ -> :metric
    end
  rescue
    _ -> :metric
  end

  defp build_to_string_code(value, unit_name, locale) do
    locale_opt =
      if to_string(locale) == "en", do: "", else: ", locale: #{inspect(to_string(locale))}"

    "{:ok, unit} = Localize.Unit.new(#{inspect(value)}, #{inspect(unit_name)})\nLocalize.Unit.to_string(unit#{locale_opt})"
  end

  defp build_new_code(value, unit_name) do
    "Localize.Unit.new(#{inspect(value)}, #{inspect(unit_name)})"
  end

  defp build_unit_name_code(unit_name) do
    "{:ok, unit} = Localize.Unit.new(value, #{inspect(unit_name)})\nunit.name"
  end

  defp build_display_name_code(unit_name, locale) do
    locale_opt =
      if to_string(locale) == "en", do: "", else: ", locale: #{inspect(to_string(locale))}"

    "Localize.Unit.display_name(#{inspect(unit_name)}#{locale_opt})"
  end

  defp build_category_code(unit_name) do
    "Localize.Unit.unit_category(#{inspect(unit_name)})"
  end

  defp build_convert_code(source_name, target_name, locale) do
    locale_opt =
      if to_string(locale) == "en", do: "", else: ", locale: #{inspect(to_string(locale))}"

    ~s|{:ok, unit} = Localize.Unit.new(value, #{inspect(source_name)})
{:ok, converted} = Localize.Unit.convert(unit, #{inspect(target_name)})
Localize.Unit.to_string(converted#{locale_opt})|
  end

  defp build_preferred_code(source_name, system, locale) do
    locale_opt =
      if to_string(locale) == "en", do: "", else: ", locale: #{inspect(to_string(locale))}"

    ~s|{:ok, unit} = Localize.Unit.new(value, #{inspect(source_name)})
{:ok, converted} = Localize.Unit.convert_measurement_system(unit, #{inspect(system)})
Localize.Unit.to_string(converted#{locale_opt})|
  end

  defp build_territory_system_code(source_name, locale) do
    locale_str = to_string(locale)
    locale_opt = if locale_str == "en", do: "", else: ", locale: #{inspect(locale_str)}"

    ~s|system = Localize.Unit.measurement_system_for_territory(territory_for(#{inspect(locale_str)}))
{:ok, unit} = Localize.Unit.new(value, #{inspect(source_name)})
{:ok, converted} = Localize.Unit.convert_measurement_system(unit, system)
Localize.Unit.to_string(converted#{locale_opt})|
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-change="update" phx-submit="update" class="lp-form" autocomplete="off">
      <.section title={gettext("Unit")}>
        <div class="lp-dt-top">
          <.field label={gettext("Locale")} for="locale">
            <input id="locale" name="locale" type="text" list="u-locales" value={@locale} phx-debounce="200" />
            <datalist id="u-locales">
              <option :for={l <- @locale_options} value={l}></option>
            </datalist>
          </.field>
        </div>
      </.section>

      <.section title={gettext("Unit")}>
        <div class="lp-unit-builder">
          <.field label={gettext("Number")} for="number">
            <input id="number" name="number" type="text" value={@number} inputmode="decimal" phx-debounce="200" />
          </.field>

          <.field label={gettext("Power")} for="source_power">
            <select id="source_power" name="source_power">
              <option :for={p <- @powers} value={p} selected={@source_power == p}>
                {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", Map.fetch!(@power_labels, p))}
              </option>
            </select>
          </.field>

          <.field label={gettext("Prefix")} for="source_prefix">
            <select id="source_prefix" name="source_prefix">
              <option :for={p <- @prefixes} value={p} selected={@source_prefix == p}>
                {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", Map.fetch!(@prefix_labels, p))}
              </option>
            </select>
          </.field>

          <.field label={gettext("Category")} for="source_category">
            <select id="source_category" name="source_category">
              <option :for={{category, _} <- @units_by_category} value={category} selected={@source_category == category}>{category}</option>
            </select>
          </.field>

          <.field label={gettext("Unit")} for="source_unit">
            <select id="source_unit" name="source_unit">
              <option :for={u <- units_for_category(@units_by_category, @source_category)} value={u} selected={@source_unit == u}>{u}</option>
            </select>
          </.field>
        </div>
      </.section>

      <.section title={gettext("Formatted output")} class="lp-result-section">
        <.result_card result={source_formatted(@source_result)} />
        <.call_code code={@source_call_code} id="u-source-call" />
        <dl class="lp-meta-table lp-unit-summary">
          <dt>{gettext("Unit name")}</dt>
          <dd class="lp-iex-value"><code>{@source_unit_name}</code></dd>
          <dt>{gettext("Display name")}</dt>
          <dd>
            <div class="lp-iex-session">
              <div class="lp-iex-line">
                <span class="lp-iex-prompt">iex&gt;</span>
                <LocalizePlaygroundWeb.HexDocs.code class="lp-iex-code" code={@display_name_code} />
              </div>
              <div class="lp-iex-result">{inspect_result(@source_result, :display_name)}</div>
            </div>
          </dd>
          <dt>{gettext("Category")}</dt>
          <dd>
            <div class="lp-iex-session">
              <div class="lp-iex-line">
                <span class="lp-iex-prompt">iex&gt;</span>
                <LocalizePlaygroundWeb.HexDocs.code class="lp-iex-code" code={@category_code} />
              </div>
              <div class="lp-iex-result">{inspect_result(@source_result, :category)}</div>
            </div>
          </dd>
        </dl>
      </.section>

      <.section title={gettext("Convert to")}>
        <div class="lp-unit-builder no-number">
          <.field label={gettext("Power")} for="target_power">
            <select id="target_power" name="target_power">
              <option :for={p <- @powers} value={p} selected={@target_power == p}>
                {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", Map.fetch!(@power_labels, p))}
              </option>
            </select>
          </.field>

          <.field label={gettext("Prefix")} for="target_prefix">
            <select id="target_prefix" name="target_prefix">
              <option :for={p <- @prefixes} value={p} selected={@target_prefix == p}>
                {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", Map.fetch!(@prefix_labels, p))}
              </option>
            </select>
          </.field>

          <.field label={gettext("Category")} for="target_category">
            <select id="target_category" name="target_category">
              <option :for={{category, _} <- @units_by_category} value={category} selected={@target_category == category}>{category}</option>
            </select>
          </.field>

          <.field label={gettext("Unit")} for="target_unit">
            <select id="target_unit" name="target_unit">
              <option :for={u <- units_for_category(@units_by_category, @target_category)} value={u} selected={@target_unit == u}>{u}</option>
            </select>
          </.field>
        </div>

        <dl class="lp-meta-table lp-unit-summary">
          <dt>{gettext("Target unit")}</dt>
          <dd><code>{@target_unit_name}</code></dd>
        </dl>

        <.call_code code={@conversion_call_code} id="u-conv-call" />
        <.result_card result={@conversion_result} />
      </.section>

      <.section title={gettext("Convert to preferred unit for measurement system")}>
        <.field label={gettext("Measurement system")} for="system">
          <select id="system" name="system">
            <option :for={{id, label} <- @systems} value={id} selected={@system == id}>
              {Gettext.dgettext(LocalizePlaygroundWeb.Gettext, "localize_playground", label)}
            </option>
          </select>
        </.field>

        <.call_code code={@preferred_call_code} id="u-pref-call" />
        <.result_card result={@preferred_result} />
      </.section>

      <.section title={gettext("Convert to preferred unit for the locale's territory")}>
        <p class="lp-muted">
          {raw(gettext("Locale {$locale} → measurement system {$system}.", locale: "<code>#{@locale}</code>", system: "<code>#{@territory_system}</code>"))}
        </p>

        <.call_code code={@territory_call_code} id="u-terr-call" />
        <.result_card result={@territory_result} />
      </.section>
    </form>
    """
  end

  defp inspect_result({:ok, %{display_name: name}}, :display_name), do: inspect({:ok, name})
  defp inspect_result({:ok, %{category: cat}}, :category), do: inspect({:ok, cat})
  defp inspect_result({:error, message}, _), do: "{:error, " <> inspect(message) <> "}"
  defp inspect_result(_, _), do: ""

  defp source_formatted({:ok, %{formatted: string}}), do: {:ok, string}
  defp source_formatted({:error, _} = error), do: error
  defp source_formatted(_), do: nil

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

  defp result_card(%{result: {:ok, string}} = assigns) when is_binary(string) do
    assigns = assign(assigns, :text, string)
    ~H|<div class="lp-result">{@text}</div>|
  end

  defp result_card(%{result: {:ok, %{formatted: string}}} = assigns) do
    assigns = assign(assigns, :text, string)
    ~H|<div class="lp-result">{@text}</div>|
  end

  defp result_card(%{result: {:error, msg}} = assigns) do
    assigns = assign(assigns, :msg, msg)
    ~H|<div class="lp-error"><strong>{gettext("Error:")}</strong> {@msg}</div>|
  end

  defp result_card(assigns), do: ~H|<div class="lp-result lp-muted">—</div>|
end
