defmodule LocalizePlaygroundWeb.LocaleView do
  @moduledoc """
  Pure helpers for the Locales tab: lists of languages/scripts/territories,
  per-language filtering, Unicode U-extension metadata, and canonical
  locale string assembly.
  """

  @u_extensions [
    {:ca, "Calendar",
     "Calendar system used for date interpretation — e.g. Gregorian, Buddhist, Hebrew."},
    {:cf, "Currency format",
     "Format style for currencies: :standard or :account (parentheses for negatives)."},
    {:cu, "Currency", "Default currency for money formatting (ISO 4217 code)."},
    {:em, "Emoji presentation", "emoji / text / default — how ambiguous glyphs render."},
    {:fw, "First day of week", "Which weekday starts a week — sun / mon / tue ... / sat."},
    {:hc, "Hour cycle", "Clock style: h11 / h12 / h23 / h24."},
    {:lb, "Line break", "loose / normal / strict line-breaking style."},
    {:lw, "Word break", "normal / breakall / keepall / phrase word-break style."},
    {:ms, "Measurement system", "metric / ussystem / uksystem."},
    {:mu, "Measurement unit", "Unit of length used in unit-aware messages."},
    {:nu, "Number system", "Numeral system for digits — latn / arab / thai / hans …"},
    {:rg, "Region override", "Override the region for region-specific data (e.g. en-u-rg-gbzzzz)."},
    {:sd, "Subdivision", "Region subdivision identifier (shown next to its localized name)."},
    {:ss, "Suppress segmentation", "none / standard — suppress word-segmentation exceptions."},
    {:tz, "Time zone", "Short UN/LOCODE-style time-zone identifier (shown next to its IANA/Olson name)."}
  ]

  @collation_extensions [
    {:co, "Collation",
     "Sort-order variant — e.g. phonebook, pinyin, stroke, traditional."},
    {:ka, "Ignore accents", "Strip accents while sorting — noignore / shifted."},
    {:kb, "Backward second-level sort", "Sort accents right-to-left — true / false."},
    {:kc, "Case-level sort", "Include case differences — true / false."},
    {:kf, "Case-first sort", "Put uppercase or lowercase first — upper / lower / false."},
    {:kh, "Hiragana-quaternary", "Distinguish hiragana vs katakana — true / false."},
    {:kk, "Normalization", "Unicode-normalize strings before sorting — true / false."},
    {:kn, "Numeric sort", "Treat digit runs as numbers — true / false."},
    {:kr, "Reordering", "Custom script-reordering list."},
    {:ks, "Sort strength", "level1 / level2 / level3 / level4 / identical."},
    {:kv, "Variable top", "Script below which characters are variable — punct / space / symbol / currency."}
  ]

  @doc """
  Returns the list of general U-extension specs in display order.
  Each entry is `{key_atom, title, description}`.
  """
  @spec u_extensions() :: [{atom(), String.t(), String.t()}]
  def u_extensions, do: @u_extensions

  @doc """
  Returns the list of collation-related U-extension specs in display
  order. Each entry is `{key_atom, title, description}`.
  """
  @spec collation_extensions() :: [{atom(), String.t(), String.t()}]
  def collation_extensions, do: @collation_extensions

  @doc """
  Returns all U-extension specs (general and collation) concatenated,
  used when seeding extensions from a locale.
  """
  @spec all_u_extensions() :: [{atom(), String.t(), String.t()}]
  def all_u_extensions, do: @u_extensions ++ @collation_extensions

  @doc """
  Returns a list of valid `{value, label}` pairs for a given U-extension
  key. For most keys `value == label`; for `:tz` the label pairs the short
  UN/LOCODE-style code with the canonical IANA/Olson identifier.
  Returns `[]` when no validity data exists (free-form text field).
  """
  @spec u_extension_values(atom(), map()) :: [{String.t(), String.t()}]
  def u_extension_values(key, context \\ %{})
  def u_extension_values(:tz, _context), do: timezone_options()
  def u_extension_values(:sd, context), do: subdivision_options(Map.get(context, :territory))
  def u_extension_values(:nu, _context), do: number_system_options()
  def u_extension_values(:ca, _context), do: calendar_options()
  def u_extension_values(:fw, _context), do: first_day_options()
  def u_extension_values(:cu, _context), do: currency_options()
  def u_extension_values(:hc, _context), do: hour_cycle_options()
  def u_extension_values(:rg, _context), do: region_override_options()
  def u_extension_values(:cf, _context), do: currency_format_options()

  # Keys whose display labels read more naturally when capitalized.
  @capitalized_label_keys [:ms, :mu, :lb, :em, :lw, :ss]

  # Keys that map "true"/"false" to "yes"/"no" — render as "Yes (true)" / "No (false)".
  @boolean_keys [:kb, :kc, :kh, :kk, :kn]

  # Hand-polished labels for specific canonical/alias strings that don't
  # split cleanly on underscore/hyphen (e.g. "uksystem" → "UK System").
  @label_overrides %{
    "uksystem" => "UK System",
    "ussystem" => "US System"
  }

  def u_extension_values(key, _context) when is_atom(key) do
    data = Localize.SupplementalData.validity(:u)
    string_key = Atom.to_string(key)
    capitalize? = key in @capitalized_label_keys
    boolean? = key in @boolean_keys

    case Map.get(data, string_key) do
      %{} = map ->
        map
        |> Enum.map(fn {canonical, alias_name} ->
          label =
            cond do
              boolean? and is_binary(alias_name) ->
                "#{String.capitalize(alias_name)} (#{canonical})"

              true ->
                value_label(canonical, alias_name, capitalize?)
            end

          {canonical, label}
        end)
        |> Enum.sort_by(fn {canonical, _label} -> canonical end)

      _ ->
        []
    end
  end

  defp value_label(canonical, alias_name, capitalize?) when is_binary(alias_name) do
    "#{polish(canonical, capitalize?)} — #{polish(alias_name, capitalize?)}"
  end

  defp value_label(canonical, _, capitalize?), do: polish(canonical, capitalize?)

  defp polish(value, capitalize?) do
    case Map.get(@label_overrides, value) do
      nil -> maybe_capitalize(value, capitalize?)
      override -> override
    end
  end

  defp maybe_capitalize(value, false), do: value

  defp maybe_capitalize(value, true) do
    value |> String.split(~r/[_-]/) |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp timezone_options do
    data = Localize.SupplementalData.validity(:u)

    (Map.get(data, "tz") || %{})
    |> Map.keys()
    |> Enum.map(&{&1, tz_label(&1)})
    |> Enum.sort_by(fn {_code, label} -> String.downcase(label) end)
  end

  defp tz_label(code) do
    case Localize.DateTime.Timezone.get_short_zone(code) do
      %{aliases: [iana | _]} -> "#{iana} (#{code})"
      _ -> code
    end
  end

  defp subdivision_options(nil), do: []
  defp subdivision_options(""), do: []

  defp subdivision_options(territory) when is_binary(territory) do
    atom =
      try do
        String.to_existing_atom(territory)
      rescue
        ArgumentError -> nil
      end

    subdivision_options(atom)
  end

  defp subdivision_options(territory) when is_atom(territory) do
    case Localize.Territory.Subdivision.for_territory(territory) do
      {:ok, list} ->
        list
        |> Enum.map(&Atom.to_string/1)
        |> Enum.map(&{&1, subdivision_label(&1)})
        |> Enum.sort_by(fn {_code, label} -> String.downcase(label) end)

      _ ->
        []
    end
  end

  defp subdivision_options(_), do: []

  defp subdivision_label(code) do
    case Localize.Territory.Subdivision.display_name(code) do
      {:ok, name} -> "#{name} (#{code})"
      _ -> code
    end
  end

  @doc """
  Returns all available BCP-47 language subtags as strings, sorted.
  """
  @spec languages() :: [String.t()]
  def languages do
    case Localize.Language.available_languages() do
      {:ok, list} -> list |> Enum.map(&to_string/1) |> Enum.sort()
      _ -> []
    end
  end

  @doc """
  Returns all ISO-15924 script codes as strings, sorted.
  """
  @spec scripts() :: [String.t()]
  def scripts do
    case Localize.Script.available_scripts() do
      {:ok, list} -> list |> Enum.map(&to_string/1) |> Enum.sort()
      _ -> []
    end
  end

  @doc """
  Returns all ISO-3166 territory codes as strings, sorted.
  """
  @spec territories() :: [String.t()]
  def territories do
    Localize.Territory.individual_territories()
    |> Enum.map(&to_string/1)
    |> Enum.sort()
  end

  @doc """
  For the given language, returns `{scripts, territories}` that appear
  in actual CLDR locale identifiers. If the language is empty or
  unknown, returns `{[], []}`.
  """
  @spec scripts_and_territories_for_language(String.t() | nil) ::
          {[String.t()], [String.t()]}
  def scripts_and_territories_for_language(lang) when is_binary(lang) and lang != "" do
    prefix = lang <> "-"

    {scripts, territories} =
      Localize.all_locale_ids()
      |> Enum.reduce({MapSet.new(), MapSet.new()}, fn id, {sc, ter} ->
        s = Atom.to_string(id)

        cond do
          s == lang ->
            {sc, ter}

          String.starts_with?(s, prefix) ->
            parts = String.split(s, "-") |> tl()
            add_script_or_territory(parts, sc, ter)

          true ->
            {sc, ter}
        end
      end)

    {Enum.sort(MapSet.to_list(scripts)), Enum.sort(MapSet.to_list(territories))}
  end

  def scripts_and_territories_for_language(_), do: {[], []}

  # A script subtag is 4 letters; territory is 2 letters or 3 digits.
  defp add_script_or_territory([], sc, ter), do: {sc, ter}

  defp add_script_or_territory([part | rest], sc, ter) do
    cond do
      script?(part) ->
        add_script_or_territory(rest, MapSet.put(sc, part), ter)

      territory?(part) ->
        add_script_or_territory(rest, sc, MapSet.put(ter, part))

      true ->
        add_script_or_territory(rest, sc, ter)
    end
  end

  defp script?(s), do: String.length(s) == 4 and String.match?(s, ~r/^[A-Z][a-z]{3}$/)

  defp territory?(s) do
    (String.length(s) == 2 and String.match?(s, ~r/^[A-Z]{2}$/)) or
      (String.length(s) == 3 and String.match?(s, ~r/^\d{3}$/))
  end

  @doc """
  Assembles a BCP-47 locale string from the given parts and U-extension
  key/value map, then returns the canonical form via
  `Localize.validate_locale/1`.

  Returns `{:ok, canonical, %Localize.LanguageTag{}}` or `{:error, message}`.
  """
  @spec build(String.t(), String.t() | nil, String.t() | nil, %{optional(atom()) => String.t()}) ::
          {:ok, String.t(), Localize.LanguageTag.t(), String.t()} | {:error, String.t()}
  def build(language, script, territory, extensions) do
    raw = assemble_locale_string(language, script, territory, extensions)

    case Localize.validate_locale(raw) do
      {:ok, %Localize.LanguageTag{} = tag} ->
        canonical = Localize.LanguageTag.to_string(tag)
        {:ok, canonical, tag, raw}

      {:error, exception} when is_exception(exception) ->
        {:error, Exception.message(exception)}

      {:error, {_mod, message}} ->
        {:error, message}
    end
  end

  @doc """
  Produces the pre-canonical locale string from the given parts (useful
  to show users what they typed before the library normalizes it).
  """
  @spec assemble_locale_string(String.t(), String.t() | nil, String.t() | nil, map()) ::
          String.t()
  def assemble_locale_string(language, script, territory, extensions) do
    base =
      [language, script, territory]
      |> Enum.reject(&blank?/1)
      |> Enum.join("-")

    u_part =
      extensions
      |> Enum.reject(fn {_k, v} -> blank?(v) end)
      |> Enum.sort_by(fn {k, _} -> Atom.to_string(k) end)
      |> Enum.flat_map(fn {k, v} -> [Atom.to_string(k), String.downcase(to_string(v))] end)

    case u_part do
      [] -> base
      parts -> Enum.join([base, "u" | parts], "-")
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  # Canonical CLDR display names for numbering systems (from ldml
  # localeDisplayNames/types where key="numbers"). Hardcoded because
  # Localize does not expose CLDR's numberingSystem display names as
  # a public API.
  @number_system_names %{
    "adlm" => "Adlam",
    "ahom" => "Ahom",
    "arab" => "Arabic-Indic",
    "arabext" => "Extended Arabic-Indic",
    "armn" => "Armenian",
    "armnlow" => "Armenian lowercase",
    "bali" => "Balinese",
    "beng" => "Bengali",
    "bhks" => "Bhaiksuki",
    "brah" => "Brahmi",
    "cakm" => "Chakma",
    "cham" => "Cham",
    "cyrl" => "Cyrillic",
    "deva" => "Devanagari",
    "diak" => "Dives Akuru",
    "ethi" => "Ethiopic",
    "finance" => "Financial",
    "fullwide" => "Full-width",
    "geor" => "Georgian",
    "gong" => "Gunjala Gondi",
    "gonm" => "Masaram Gondi",
    "grek" => "Greek",
    "greklow" => "Greek lowercase",
    "gujr" => "Gujarati",
    "guru" => "Gurmukhi",
    "hanidays" => "Chinese calendar day-of-month",
    "hanidec" => "Chinese decimal",
    "hans" => "Simplified Chinese",
    "hansfin" => "Simplified Chinese financial",
    "hant" => "Traditional Chinese",
    "hantfin" => "Traditional Chinese financial",
    "hebr" => "Hebrew",
    "hmng" => "Pahawh Hmong",
    "hmnp" => "Nyiakeng Puachue Hmong",
    "java" => "Javanese",
    "jpan" => "Japanese",
    "jpanfin" => "Japanese financial",
    "jpanyear" => "Japanese calendar year",
    "kali" => "Kayah Li",
    "kawi" => "Kawi",
    "khmr" => "Khmer",
    "knda" => "Kannada",
    "lana" => "Tai Tham Hora",
    "lanatham" => "Tai Tham Tham",
    "laoo" => "Lao",
    "latn" => "Latin",
    "lepc" => "Lepcha",
    "limb" => "Limbu",
    "mathbold" => "Mathematical bold",
    "mathdbl" => "Mathematical double-struck",
    "mathmono" => "Mathematical monospace",
    "mathsanb" => "Mathematical sans-serif bold",
    "mathsans" => "Mathematical sans-serif",
    "mlym" => "Malayalam",
    "modi" => "Modi",
    "mong" => "Mongolian",
    "mroo" => "Mro",
    "mtei" => "Meetei Mayek",
    "mymr" => "Myanmar",
    "mymrepka" => "Myanmar Eastern Pwo Karen",
    "mymrpao" => "Myanmar Pao",
    "mymrshan" => "Myanmar Shan",
    "mymrtlng" => "Myanmar Tai Laing",
    "nagm" => "Nag Mundari",
    "native" => "Native",
    "newa" => "Newa",
    "nkoo" => "N'Ko",
    "olck" => "Ol Chiki",
    "onao" => "Ol Onal",
    "orya" => "Oriya",
    "osma" => "Osmanya",
    "outlined" => "Outlined",
    "rohg" => "Hanifi Rohingya",
    "roman" => "Roman",
    "romanlow" => "Roman lowercase",
    "saur" => "Saurashtra",
    "shrd" => "Sharada",
    "sind" => "Khudawadi",
    "sinh" => "Sinhala Lith",
    "sora" => "Sora Sompeng",
    "sund" => "Sundanese",
    "takr" => "Takri",
    "talu" => "New Tai Lue",
    "taml" => "Tamil",
    "tamldec" => "Tamil decimal",
    "tangut" => "Tangut",
    "telu" => "Telugu",
    "thai" => "Thai",
    "tibt" => "Tibetan",
    "tirh" => "Tirhuta",
    "tnsa" => "Tai Nüa",
    "traditio" => "Traditional",
    "traditional" => "Traditional",
    "vaii" => "Vai",
    "wara" => "Warang Citi",
    "wcho" => "Wancho"
  }

  defp number_system_options do
    data = Localize.SupplementalData.validity(:u)

    (Map.get(data, "nu") || %{})
    |> Map.keys()
    |> Enum.map(fn code -> {code, number_system_label(code)} end)
    |> Enum.sort_by(fn {_code, label} -> label end)
  end

  defp number_system_label(code) do
    case Map.get(@number_system_names, code) do
      nil -> code
      name -> "#{name} (#{code})"
    end
  end

  defp calendar_options do
    data = Localize.SupplementalData.validity(:u)
    ca_map = Map.get(data, "ca") || %{}

    ca_map
    |> Enum.map(fn {canonical, alias_name} ->
      {canonical, calendar_label(canonical, alias_name)}
    end)
    |> Enum.sort_by(fn {_code, label} -> String.downcase(label) end)
  end

  defp calendar_label(canonical, alias_name) do
    name =
      lookup_calendar_name(canonical) || lookup_calendar_name(alias_name) || canonical

    # The API returns "Gregorian Calendar"; drop the word "Calendar"
    # anywhere in the string since the panel title already tells the
    # user what these are.
    short = name |> String.replace(~r/\s*\bCalendar\b\s*/, " ") |> String.trim()
    "#{short} (#{canonical})"
  end

  defp lookup_calendar_name(nil), do: nil

  @day_names %{
    "sun" => "Sunday",
    "mon" => "Monday",
    "tue" => "Tuesday",
    "wed" => "Wednesday",
    "thu" => "Thursday",
    "fri" => "Friday",
    "sat" => "Saturday"
  }

  @day_order %{"mon" => 1, "tue" => 2, "wed" => 3, "thu" => 4, "fri" => 5, "sat" => 6, "sun" => 7}

  @hour_cycle_names %{
    "h11" => "12-hour (0–11)",
    "h12" => "12-hour (1–12)",
    "h23" => "24-hour (0–23)",
    "h24" => "24-hour (1–24)"
  }

  @currency_format_names %{
    "standard" => "Standard",
    "account" => "Accounting"
  }

  defp currency_format_options do
    data = Localize.SupplementalData.validity(:u)
    cf_map = Map.get(data, "cf") || %{}

    cf_map
    |> Map.keys()
    |> Enum.map(fn code ->
      name = Map.get(@currency_format_names, code, code)
      {code, "#{name} (#{code})"}
    end)
    |> Enum.sort_by(fn {_code, label} -> label end)
  end

  defp region_override_options do
    Localize.Territory.individual_territories()
    |> Enum.map(fn atom ->
      code = atom |> Atom.to_string() |> String.downcase()
      name =
        case Localize.Territory.display_name(atom) do
          {:ok, display} -> display
          _ -> Atom.to_string(atom)
        end

      # CLDR encodes -u-rg values as "<lowercase-region>zzzz"
      {"#{code}zzzz", "#{name} (#{String.upcase(code)})"}
    end)
    |> Enum.sort_by(fn {_v, label} -> String.downcase(label) end)
  end

  defp hour_cycle_options do
    data = Localize.SupplementalData.validity(:u)
    hc_map = Map.get(data, "hc") || %{}

    hc_map
    |> Map.keys()
    |> Enum.map(fn code ->
      name = Map.get(@hour_cycle_names, code, code)
      {code, "#{name} (#{code})"}
    end)
    |> Enum.sort_by(fn {code, _} -> code end)
  end

  defp currency_options do
    data = Localize.SupplementalData.validity(:u)
    cu_map = Map.get(data, "cu") || %{}

    cu_map
    |> Map.keys()
    |> Enum.map(fn code -> {code, currency_label(code)} end)
    |> Enum.sort_by(fn {_code, label} -> String.downcase(label) end)
  end

  defp currency_label(code) do
    case Localize.Currency.display_name(String.upcase(code)) do
      {:ok, name} -> "#{name} (#{code})"
      _ -> code
    end
  end

  defp first_day_options do
    data = Localize.SupplementalData.validity(:u)
    fw_map = Map.get(data, "fw") || %{}

    fw_map
    |> Map.keys()
    |> Enum.map(fn code ->
      name = Map.get(@day_names, code, code)
      {code, "#{name} (#{code})"}
    end)
    |> Enum.sort_by(fn {code, _} -> Map.get(@day_order, code, 99) end)
  end

  defp lookup_calendar_name(name) when is_binary(name) do
    atom =
      try do
        String.to_existing_atom(name)
      rescue
        ArgumentError -> nil
      end

    case atom && Localize.Calendar.display_name(:calendar, atom) do
      {:ok, display} -> display
      _ -> nil
    end
  end
end
