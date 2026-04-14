defmodule LocalizePlaygroundWeb.CollationView do
  @moduledoc """
  Pure helpers for the Collation tab: per-locale seed word lists,
  collation variant lookup, and sort invocation.
  """

  # A small, carefully-chosen set of words per locale. Each list aims
  # to exercise cases that sorting rules actually move around: mixed
  # case, accented variants paired with their ASCII forms, and any
  # locale-specific glyphs (ß, ñ, ij, é, etc.) that let tailorings
  # show their effect.
  @seed_words %{
    "en" => ~w(apple Apple banana Banana café cafe Cafe résumé resume zebra),
    "fr" => ~w(cote côte coté côté coeur cœur père pere PÈRE peru),
    "de" => ~w(Müller Mueller Muller strasse straße Straße Zürich Oel Öl Weiß),
    "it" => ~w(città citta perché perche è e uomo uòmo cosa così),
    "es" => ~w(ñandú nino niño llama luna chico cabra coche amigo zorro),

    # Slavic, Latin script. Words chosen to exercise each language's
    # diacritics and digraphs — notably "ch" in Czech/Slovak which
    # sorts after "h", and Polish "ł" / "ś" / "ż" which follow their
    # base letters.
    "cs" => ~w(čas chléb dům hora kočka noc řeka šéf zelený žena),
    "sk" => ~w(čas chlieb dom hora ľad nôta rok škola ženích živý),
    "pl" => ~w(abak ązab cień ćma dom łoś Nowak ogród świat żuraw),
    "sl" => ~w(cesta čas dom hiša reka sončen šola zebra žaba živalca),
    "hr" => ~w(car čas ćao dan džep đak ljeto njega riba škola žena),

    # Slavic, Cyrillic script. Demonstrates how the tailored alphabet
    # orders language-specific letters (Ukrainian ґ, є, ї, Serbian ђ,
    # љ, њ, Macedonian ѓ, ѕ, ќ, Bulgarian ъ, etc.).
    "ru" => ~w(арбуз бабушка волк гриб дом ёлка жизнь забор игра ягода),
    "uk" => ~w(абрикос бджола відро ґрунт дорога єдність жовтень зірка їжак яблуко),
    "bg" => ~w(автор бяло вода град дом жена зелен изкуство къща ябълка),
    "sr" => ~w(агент брат виши говор дан ђак жао љубав њива царина),
    "mk" => ~w(автор бел град ѓавол дружба ѕвезда живот јаглен љубов њива),

    # East Asian. Chinese words are chosen so that the three main
    # tailorings (pinyin, stroke, zhuyin) visibly reorder the list:
    # simple-stroke characters come first under "stroke", but in
    # pinyin alphabetical order they are scattered.
    "zh" => ~w(一 人 山 水 中国 北京 上海 你好 谢谢 再见),

    # Japanese mixes hiragana, katakana and kanji. The default
    # tailoring sorts kana by gojūon order (あいうえお…) and keeps
    # same-reading forms together.
    "ja" => ~w(あめ アイス 桜 さくら サクラ 富士山 東京 おはよう こんにちは ありがとう),

    # Korean Hangul syllables. Sort order follows jamo sequence
    # ㄱ ㄲ ㄴ ㄷ … (the reason 바나나 comes after 나).
    "ko" => ~w(가족 고양이 나무 다리 바나나 사과 안녕 아이 저녁 한국)
  }

  @doc """
  Returns the default word list for the given language. Falls back to
  the `en` list when no seed exists for the language.
  """
  @spec seed_words(String.t()) :: [String.t()]
  def seed_words(language) when is_binary(language) do
    Map.get(@seed_words, String.downcase(language), @seed_words["en"])
  end

  @doc """
  Returns the list of collation variant atoms available for a given
  language — e.g. `[:standard, :phonebk, :traditional]` for `de`.
  """
  @spec available_collations(String.t()) :: [atom()]
  def available_collations(language) when is_binary(language) and language != "" do
    lang_code = String.downcase(language)

    Localize.Collation.Tailoring.supported_locales()
    |> Enum.filter(fn {loc, _variant} -> loc == lang_code end)
    |> Enum.map(fn {_loc, variant} -> variant end)
    |> Enum.reject(&(&1 == :search))
    |> Enum.uniq()
    |> ensure_standard()
    |> Enum.sort_by(&sort_rank/1)
  end

  def available_collations(_), do: [:standard]

  # Always surface :standard first even if the tailoring table only
  # exposes variants.
  defp ensure_standard(list) do
    if :standard in list, do: list, else: [:standard | list]
  end

  # Keep :standard first, then alphabetical.
  defp sort_rank(:standard), do: {0, ""}
  defp sort_rank(other), do: {1, Atom.to_string(other)}

  @doc """
  Sorts the given words using Localize.Collation. Returns `{:ok, sorted}`
  or `{:error, message}`.
  """
  @spec sort([String.t()], keyword()) :: {:ok, [String.t()]} | {:error, String.t()}
  def sort(words, options) do
    {:ok, Localize.Collation.sort(words, options)}
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  @doc """
  Options relevant to collation, in a display order that matches the
  mental model of "strength → case → accents → punctuation → numbers".
  Each entry is `{key, title, description, kind, choices}` where `kind`
  is `:select | :checkbox` and `choices` is the option list (ignored
  for checkboxes).
  """
  def option_specs do
    [
      {:strength, "Strength",
       "How fine-grained the comparison is. Higher strength distinguishes more differences (case, accents).",
       :select,
       [
         {"", "(locale default)"},
         {"primary", "Primary — base letters only"},
         {"secondary", "Secondary — also accents"},
         {"tertiary", "Tertiary — also case"},
         {"quaternary", "Quaternary — also punctuation"},
         {"identical", "Identical — full code-point"}
       ]},
      {:alternate, "Alternate",
       "Whether punctuation and whitespace carry weight. `Shifted` pushes them to the last level.",
       :select,
       [
         {"", "(locale default)"},
         {"non_ignorable", "Non-ignorable (default)"},
         {"shifted", "Shifted"}
       ]},
      {:case_first, "Case first",
       "When strength ≥ tertiary, whether uppercase or lowercase sorts first.",
       :select,
       [
         {"", "(locale default)"},
         {"upper", "Upper first"},
         {"lower", "Lower first"}
       ]},
      {:max_variable, "Max variable",
       "Which classes of characters are treated as variable-weight when alternate = shifted.",
       :select,
       [
         {"", "(locale default)"},
         {"punct", "Punctuation (default)"},
         {"space", "Space"},
         {"symbol", "Symbol"},
         {"currency", "Currency"}
       ]},
      {:case_level, "Case level",
       "Inserts a dedicated case comparison level. Lets primary strength still distinguish case.",
       :checkbox, nil},
      {:backwards, "Backwards secondary (French)",
       "Reverses the secondary level — the classic French accent rule.",
       :checkbox, nil},
      {:normalization, "NFD normalization",
       "Canonicalize input before comparing. Usually only needed for unusual source data.",
       :checkbox, nil},
      {:numeric, "Numeric mode",
       "Treat digit runs as numbers (so `item2` sorts before `item10`).",
       :checkbox, nil}
    ]
  end

  @doc """
  Builds the Localize.Collation option keyword list from a map of
  UI-facing values. Empty-string values mean "use the locale default"
  and are dropped.
  """
  @spec build_options(String.t(), atom(), map()) :: keyword()
  def build_options(locale, collation, ui_options) do
    locale_option =
      case {locale, collation} do
        {"", :standard} -> []
        {"", variant} -> [locale: "und-u-co-#{collation_code(variant)}"]
        {loc, :standard} -> [locale: loc]
        {loc, variant} -> [locale: "#{loc}-u-co-#{collation_code(variant)}"]
      end

    extras =
      ui_options
      |> Enum.reduce([], fn {key, raw_value}, acc ->
        case coerce_option(key, raw_value) do
          nil -> acc
          value -> [{key, value} | acc]
        end
      end)
      |> Enum.reverse()

    locale_option ++ extras
  end

  # The Localize.Collation.Tailoring table uses CLDR's full names
  # (`:phonebook`, `:traditional`) but the BCP-47 `-u-co-` subtag
  # requires the canonical 3-8-char code (`phonebk`, `trad`). Build a
  # reverse map once from the validity data: alias_long → canonical.
  @co_name_to_code (Localize.SupplementalData.validity(:u)
                    |> Map.get("co", %{})
                    |> Enum.reduce(%{}, fn
                      {canonical, alias_name}, acc when is_binary(alias_name) ->
                        Map.put(acc, alias_name, canonical)

                      {canonical, _}, acc ->
                        Map.put(acc, canonical, canonical)
                    end))

  defp collation_code(:standard), do: "standard"

  defp collation_code(variant) when is_atom(variant) do
    name = variant |> Atom.to_string() |> String.downcase()

    Map.get(@co_name_to_code, name, name |> String.replace("_", "-"))
  end

  defp coerce_option(_, ""), do: nil
  defp coerce_option(_, nil), do: nil
  defp coerce_option(_, false), do: nil

  defp coerce_option(:strength, value), do: String.to_existing_atom(value)
  defp coerce_option(:alternate, value), do: String.to_existing_atom(value)
  defp coerce_option(:case_first, value), do: String.to_existing_atom(value)
  defp coerce_option(:max_variable, value), do: String.to_existing_atom(value)
  defp coerce_option(:case_level, true), do: true
  defp coerce_option(:backwards, true), do: true
  defp coerce_option(:normalization, true), do: true
  defp coerce_option(:numeric, true), do: true
  defp coerce_option(_, _), do: nil
end
