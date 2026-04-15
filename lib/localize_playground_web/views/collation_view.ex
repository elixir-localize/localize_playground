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
    "ko" => ~w(가족 고양이 나무 다리 바나나 사과 안녕 아이 저녁 한국),

    # ---------- Latin: Germanic / Scandinavian ----------
    "da" => ~w(aften bjerg dag øst ære æble århus åben zebra zoo),
    "no" => ~w(aften berg dag øst ære æple ålesund åpen zebra zoo),
    "sv" => ~w(aften berg dag äpple ögon åker zebra zoo ökän åska),
    "is" => ~w(afi bók dagur ævi öld þing þorp yfir ýmis óður ísi),
    "fo" => ~w(afi brot dag ær ø åa þorp ýmis),
    "af" => ~w(appel baba hond klein môre oma straat tante vrou wyn),
    "fy" => ~w(appel bern dei foark eagje hûs ien joun ko mem),

    # ---------- Latin: Finno-Ugric ----------
    "fi" => ~w(aamu ilma joki kesä lumi meri päivä sää yö ääni),
    "et" => ~w(aare ema ilm järv keel küla pere sõber tee üks õhtu),
    "hu" => ~w(alma csaba dal gyűrű lyuk nyár szem tűz ünnep zászló zsír),
    "se" => ~w(áhkku beana čuovga doahppu eatni goahti njunnes šattolaš),

    # ---------- Latin: Baltic ----------
    "lt" => ~w(ąžuolas beržas čia drėbti ėsti geras įrankis knyga šalis žmogus),
    "lv" => ~w(ābols čigāns drūms ēna īss ķirsis ļauns meža ņemt šalle žagata),

    # ---------- Latin: Celtic ----------
    "cy" => ~w(cath chwaer dyn ddysgu ffordd ng hy llyn rhedeg thyst),

    # ---------- Latin: Romance (remaining) ----------
    "ca" => ~w(àvia català època enciam farina hivern ínsula òptim pluja sí),
    "ro" => ~w(ales băț cârnat doină fum împărat înger nor parc ștampilă țap),
    "gl" => ~w(auga casa día follaxe home lúa mesa niño pan rúa),
    "pt" => ~w(açúcar água bala casa dúvida é enxame fé língua nação),
    "eo" => ~w(bona ĉokolado domo eĉ ĝojo ĥoro ĵurnalo kuracisto ŝati ŭnikoda),
    "mt" => ~w(ajruplan bieb ċitt ġawhra għama ħabib it mejda rebħa żmien),
    "sq" => ~w(aeroplan buzë çaj dhëmb ëndërr gjysh jetë llambë nënë pastërti shok),

    # ---------- Latin: Turkic / Altaic ----------
    "tr" => ~w(ağa bahçe çay dağ giriş hasat ışık İstanbul kızıl öğrenci pamuk şeker),
    "az" => ~w(acı bağ çay dəniz ələk gün hövsələ işıq kənd oğlan öküz şəhər),
    "uz" => ~w(ariq bola gilos dastur hokim ish kun maktab oʻqituvchi soat yoʻl),
    "tk" => ~w(agaç bagşy çörek dag ene guşak işik kitap mekdep nahar öý şeker),
    "kk" => ~w(ана бала ғалым да ел желтоқсан зауыт ин көл құс ң өзен шаш),
    "ky" => ~w(ата бала дос жаан ит кол мектеп ноокат өзөн сүйүү таш),

    # ---------- Latin: Southeast Asian / tonal ----------
    "vi" => ~w(ba bà bá bả bã bạ cà cá mà má mạ ngày nghĩa),

    # ---------- Latin: African ----------
    "ha" => ~w(bera ɓera ɗaya dagɔ duka kafa sanya taimako yaro ƙofa),
    "yo" => ~w(apá ẹja iyán òkun orí ọmọ ṣọ́bì tútù wa yàrá),
    "ig" => ~w(ahụ bụ chọ dị ekele gbọ iheọma kpị mma ọma ụmụ),
    "wo" => ~w(ànd bokk dafa ëllëg góor jigéen lew neel tàmbali waa),
    "ee" => ~w(agbo ɖevi ƒe gbɔ haya ɣe lã mi nɔvi ŋku ɔkra ʋu),
    "om" => ~w(abbaa baala caalaa dhadhaa gootichaa haala jechaa qabsoo),
    "lkt" => ~w(aŋpétu bloká čha čhaŋté glépi háŋhepi iŋa kiŋ lakhóta),
    "so" => ~w(aabbe beer cayn dhar eeg geesi hoy iraq jaal qaad),

    # ---------- Latin: other ----------
    "haw" => ~w(aloha hale ʻāina kai mele nui ola pua wai),
    "vo" => ~w(blüf fam gas hel kad lom nem pel ro sül),
    "fil" => ~w(araw bata dalaga ganda hayop ina kape lola mahal ngayon saya),

    # ---------- Cyrillic (remaining) ----------
    "be" => ~w(абітурыент бел горад дом ёлка жыццё іран канец лес мая ўсе час шчасце),
    "mn" => ~w(ахуй бага газар дом есөн жил зам өнөөдөр тусгаар үзэсгэлэн ю я),
    "cu" => ~w(азъ боукы вѣдѣ глаголь добро есть живѣте ꙁемꙗ ижеи како людꙗ),

    # ---------- Greek ----------
    "el" => ~w(άρτος βιβλίο γέρος δέντρο έτος ζωή θάλασσα ήλιος ξένος υγεία ψυχή ωραίος),

    # ---------- Armenian ----------
    "hy" => ~w(աշակերտ բարի գիտություն դաս եղբայր զգեստ էական թագավոր ժամանակ ինչ լույս),

    # ---------- Georgian ----------
    "ka" => ~w(აბანო ბავშვი გაზაფხული დედა ვერცხლი ზაფხული თავი კატა მთა სახლი ჭადარი ჯანმრთელობა),

    # ---------- Arabic-script ----------
    "ar" => ~w(أب أم بيت تفاحة ثلج جمل حليب خبز دار ربيع زرافة سمك شمس قمر مفتاح),
    "fa" => ~w(آب بهار پدر تابستان ثمر جنگل چای حق دل ذهن ر ز),
    "ur" => ~w(آم باپ پانی تارا جنگ حصہ دل ذہن سمندر شام قلم میں یار),
    "ps" => ~w(اثر بارون پلار ټوټه څنګه حوض درد ځلمی ژبه سپین ک مور),
    "he" => ~w(אב אם בית גן דג הר וו זמן חג יום כלב לילה מים נוף סוף עולם שלום),

    # ---------- Indic ----------
    "hi" => ~w(अनार आम इमली ईख उल्लू ऊँट गाय घर चाय दूध पानी फल भालू मछली),
    "mr" => ~w(आई उंट ऊब एकता काकडी खेळ गावा घर डॉक्टर तारा पाणी मुल),
    "sa" => ~w(अगस्त्य आत्मा इन्द्र ईश्वर उत्तर ऋषि एक ऐक्य ओंकार औषधि कमल ज्ञान),
    "bn" => ~w(আম ইঁদুর ঈগল উট ঊষা এক ওষুধ কলম খবর গান ঘুম চায়া),
    "or" => ~w(ଆଇ ଇଳ ଉଆସ ଏକ କଇଡ଼ ଖଇ ଗଳ ଚଷ ଜଳ ଟେକ ଣ ତର),
    "pa" => ~w(ਆਮ ਇੱਕ ਈਸਾ ਉਚਾਈ ਏਕਤਾ ਕਹਾਣੀ ਖਾਣਾ ਗੱਲ ਘਰ ਚੱਲ),
    "gu" => ~w(અગત આમળાં ઈંટ ઉનાળો ઊંટ એક ઓરડો કૃષ્ણ ખેતર ગામ),
    "kn" => ~w(ಅಕ್ಷರ ಆನೆ ಇಲಿ ಈಶ ಉರಿ ಏಕ ಓದು ಕಣ್ಣು ಖಗ ಗಾನ),
    "ml" => ~w(അമ്മ ആന ഇര ഈശ ഉപ്പ് ഏകാഗ്രത ഓണം കണ്ണ് ഖണ്ഡം ഗാനം),
    "ta" => ~w(அம்மா ஆடு இலை ஈ உலகம் எறும்பு ஏழு கண் சந்திரன் தமிழ் நாய் பழம் மழை),
    "te" => ~w(అమ్మ ఆవు ఇల్లు ఈశ ఉల్లి ఎరుపు ఓం కలం ఖగం గాలి చదువు త్యాగం),
    "si" => ~w(අම්මා ආත්මය ඉඟුරු උඩ ඌරා ඍ එලි කාලය ගස ජල ධනය),
    "ne" => ~w(आमा बच्चा गाउँ घर चिया डोको तारा धरती पाखुरा फुल),

    # ---------- Southeast Asian scripts ----------
    "th" => ~w(กา ขา คน งู จาน ฉันทา ช้าง ดาว ตา ถ้า ทะเล นก ผลไม้ ฝน รัก),
    "lo" => ~w(ກາ ຂ ຄ ງ ຈ ຊ ດ ຕ ຖ ທ ນ ປ ພ ມ ຍ),
    "km" => ~w(កណ្តុរ ខាងកើត គ្រូ ឆ្កែ ជួប ដ ត ថ ទ នក ផ្កា ភ្នំ ស្វាយ),
    "my" => ~w(ကျွန်တော် ခင်ဗျား ဂ ဃ င စ ဆ ဇ ဈ ည ဋ),

    # ---------- Tibetan / Dzongkha ----------
    "bo" => ~w(ཀ ཁ ག ང ཅ ཆ ཇ ཉ ཏ ཐ ད ན པ ཕ བ མ),
    "dz" => ~w(ཀ ཁ ག ང ཅ ཆ ཇ ཉ ཏ ཐ ད ན པ ཕ བ),

    # ---------- Ethiopic / Semitic (non-Arabic) ----------
    "am" => ~w(ሀ ለ ሐ መ ሠ ረ ሰ ሸ ቀ በ ተ ቸ ኀ ነ ኘ አ),
    "ti" => ~w(ሀ ለ ሐ መ ሰ ረ ሸ ቀ በ ተ ቸ ኀ ነ ኘ),
    "chr" => ~w(Ꭰ Ꭱ Ꭲ Ꭳ Ꭴ Ꭵ Ꭶ Ꭷ Ꭸ Ꭹ Ꭺ Ꭻ Ꭼ Ꭽ)
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
  Returns the hex representation of each word's CLDR sort key under
  the given options, useful for explaining why the order came out
  the way it did.
  """
  @spec sort_keys([String.t()], keyword()) :: [{String.t(), String.t()}]
  def sort_keys(words, options) do
    Enum.map(words, fn word ->
      key =
        try do
          Localize.Collation.sort_key(word, options)
        rescue
          _ -> <<>>
        end

      {word, format_key(key)}
    end)
  end

  defp format_key(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map_join(" ", &:io_lib.format("~2.16.0B", [&1]) |> IO.iodata_to_binary())
  end

  @doc """
  Compares two strings under the given options. Returns
  `:lt | :eq | :gt` or `{:error, message}`.
  """
  @spec compare(String.t(), String.t(), keyword()) :: :lt | :eq | :gt | {:error, String.t()}
  def compare(a, b, options) do
    Localize.Collation.compare(a, b, options)
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  # Per-language captions for the seed word list. Each string is a
  # one-line hint that tells the user what to watch for when they
  # change the collation variant or options.
  @seed_captions %{
    "en" => "Standard English mixes case and accented forms — try strength = primary to collapse them.",
    "fr" => "Toggle Backwards-secondary (French) to see côté / coté swap because accent order reads right-to-left.",
    "de" => "Switch between Standard and Phonebook — Phonebook treats ü like ue, so Müller moves between Mueller and Muller.",
    "it" => "Primary strength ignores the accents on città, perché, così.",
    "es" => "Switch between Standard and Traditional — Traditional splits ch and ll into their own letters after c and l.",
    "cs" => "Notice that chléb sorts after hora — ch is a single letter in Czech, positioned after h.",
    "sk" => "Like Czech, ch is one letter; note ľ and ô in their tailored slots.",
    "pl" => "ą / ć / ł / ń / ś / ź / ż each sit directly after their base letter, never collapsed into them.",
    "sl" => "Slovene adds only č, š, ž — cleaner than neighbours but still distinct from their unaccented forms.",
    "hr" => "Digraphs dž, lj, nj each act as a single letter — lj sorts between l and m, not inside l.",
    "ru" => "Standard Russian alphabet order; ё is usually folded into е unless strength is tertiary+.",
    "uk" => "ґ sorts after г, є after е, ї after і — Ukrainian adds letters Russian doesn't have.",
    "bg" => "No special letters beyond the shared Cyrillic base — shows baseline Cyrillic ordering.",
    "sr" => "Serbian Cyrillic order: ђ after д, љ after л, њ after н.",
    "mk" => "Macedonian adds ѓ, ѕ, ј, љ, њ, ќ, џ — each tailored between its Cyrillic neighbours.",
    "zh" => "Switch between Pinyin / Stroke / Zhuyin to see the same characters reorder completely.",
    "ja" => "Kana sort in gojūon order first, kanji follow — switch to Unihan to reorder the kanji block.",
    "ko" => "Hangul sorts by jamo: ㄱ → ㄴ → ㄷ → ㅂ → ㅅ → ㅇ → ㅈ → ㅎ.",
    "da" => "æ / ø / å sort after z in Danish — the opposite of what codepoint order would give you.",
    "sv" => "Swedish: ä / ö / å all come after z, in that specific order.",
    "is" => "Icelandic has ð (after d), þ (after z), æ (after y), ö (after z).",
    "hu" => "Digraphs cs / gy / ly / ny / sz / zs each behave as single letters between their base letters.",
    "fi" => "Finnish ä and ö sort after z, like Swedish.",
    "tr" => "Dotted İ / i vs dotless I / ı — these are different letters in Turkish, never collapsed.",
    "vi" => "Tone marks alter the secondary level — ba, bà, bá, bả, bã, bạ is the canonical tone order.",
    "lt" => "ą, č, ę, ė, į, š, ų, ū, ž — each in tailored positions.",
    "lv" => "Latvian inserts č, ģ, ķ, ļ, ņ, š, ž into the tailored slots.",
    "ar" => "Arabic follows the abjadi order; hamza-bearing forms (أ, إ, آ) normalise to alif at primary strength.",
    "he" => "Hebrew letters in their canonical order; final-forms (ך ם ן ף ץ) collate with their primary forms.",
    "el" => "Greek lower/upper forms fold at tertiary strength; accented vowels fold at secondary.",
    "th" => "Thai ordering follows the Royal Institute sequence ก ข ฃ ค ฅ ฆ…",
    "hi" => "Devanagari vowel + consonant order; vowel signs collate with their independent forms."
  }

  @doc """
  Returns a short human-readable hint explaining what the seed word
  list demonstrates for the given language, or `nil` if no caption
  is defined.
  """
  @spec seed_caption(String.t()) :: String.t() | nil
  def seed_caption(language) when is_binary(language) do
    Map.get(@seed_captions, String.downcase(language))
  end

  def seed_caption(_), do: nil

  # One-click combinations that set multiple collation options. Each
  # entry is `{id, label, description, option_map}` — the option_map
  # is merged into the current options when applied.
  @presets [
    {:default, "Default", "Clear every override.", %{}},
    {:case_insensitive, "Case-insensitive", "Collapses uppercase and lowercase.",
     %{strength: "secondary"}},
    {:accent_insensitive, "Accent-insensitive", "Ignores accents and case.",
     %{strength: "primary"}},
    {:punctuation_insensitive, "Ignore punctuation",
     "Spaces and punctuation drop to the lowest level.", %{alternate: "shifted"}},
    {:natural_numbers, "Natural numbers",
     "Digit runs compared as numbers — item2 before item10.", %{numeric: true}},
    {:uppercase_first, "Uppercase first", "Applied at tertiary strength.",
     %{case_first: "upper"}},
    {:french_accents, "French accents",
     "Reverses the secondary level, the classic French accent rule.",
     %{backwards: true}}
  ]

  @doc """
  Returns the preset definitions used by the UI.
  """
  @spec presets() :: [{atom(), String.t(), String.t(), map()}]
  def presets, do: @presets

  @doc """
  Returns the option map for a named preset, or `nil` if unknown.
  """
  @spec preset_options(atom()) :: map() | nil
  def preset_options(id) do
    Enum.find_value(@presets, fn {name, _, _, opts} -> name == id && opts end) || nil
  end

  @doc """
  Returns a fresh "all defaults" options map for the given option specs.
  """
  @spec default_options([tuple()]) :: map()
  def default_options(option_specs) do
    for {key, _title, _desc, kind, _choices} <- option_specs, into: %{} do
      case kind do
        :checkbox -> {key, false}
        :select -> {key, ""}
      end
    end
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

  @doc """
  Returns the ordered list of choices for the -u-kr reorder-code
  picker. Script atoms come from `Localize.Script.available_scripts/0`;
  CLDR-defined special groups are prepended.
  """
  @spec reorder_choices() :: [{String.t(), String.t()}]
  def reorder_choices do
    specials = [
      {"digit", "digit — digits"},
      {"punct", "punct — punctuation"},
      {"symbol", "symbol — general symbols"},
      {"currency", "currency — currency symbols"},
      {"space", "space — whitespace"},
      {"others", "others — everything else"}
    ]

    scripts =
      case Localize.Script.available_scripts() do
        {:ok, list} ->
          list
          |> Enum.map(&{to_string(&1), to_string(&1)})
          |> Enum.sort_by(fn {_code, label} -> label end)

        _ ->
          []
      end

    specials ++ scripts
  end

  @doc """
  Converts the UI's list of string codes into the atom list that
  `Localize.Collation.sort/2` expects for the `:reorder` option.
  """
  @spec normalize_reorder([String.t()]) :: [atom()]
  def normalize_reorder(codes) do
    codes
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map(&String.to_atom/1)
  end
end
