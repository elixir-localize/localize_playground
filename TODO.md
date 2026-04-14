# Localize Playground — TODO

## Collation tab

### Seed word lists — minority / indigenous languages

`Localize.Collation.Tailoring.supported_locales/0` exposes 116 tailored
locales. `CollationView.@seed_words` currently covers the ~50 languages
where I could produce genuinely representative words drawn from common
vocabulary. The remaining tailored locales fall back to the `en` seed
list, which defeats the point of showcasing their tailoring.

These still need properly curated 10-word seed lists written by someone
with native/working knowledge of each orthography (a synthetic list of
"one word per alphabet letter" is less useful than words that actually
move around under the tailoring):

| Locale | Language | Notes |
|--------|----------|-------|
| `aa` | Afar | Latin |
| `bal`, `bal-Latn` | Baluchi | Arabic / Latin |
| `blo` | Anii | Latin |
| `br` | Breton | Latin, has some tailoring |
| `bs`, `bs-Cyrl` | Bosnian (both scripts) | already covered by `hr` sibling, but BCP-47 wise distinct |
| `ceb` | Cebuano | Latin |
| `cy` | Welsh | covered — digraphs ch, dd, ff, ng, ll, ph, rh, th |
| `de-AT` | Austrian German | inherits `de` seeds (fine) |
| `dsb`, `hsb` | Lower / Upper Sorbian | Latin |
| `en-US-POSIX` | POSIX ordering | codepoint test — use ASCII subset |
| `ff-Adlm` | Fulah (Adlam script) | Adlam alphabet |
| `fr-CA` | Canadian French | inherits `fr` (fine) |
| `kk-Arab` | Kazakh (Arabic script) | separate from Cyrillic `kk` |
| `kl` | Kalaallisut (Greenlandic) | Latin |
| `kok` | Konkani | Devanagari |
| `ku` | Kurdish | Latin |
| `ln` | Lingala | Latin |
| `nso` | Northern Sotho | Latin |
| `sgs` | Samogitian | Latin |
| `smn` | Inari Sami | Latin |
| `sr-Latn` | Serbian (Latin) | inherits `hr` seeds loosely, but distinct tailoring |
| `ssy` | Saho | Latin |
| `to` | Tongan | Latin |
| `ug` | Uyghur | Arabic script |
| `und` | Root / default | probably skip — pointless to seed |
| `wae` | Walser | Latin |
| `yi` | Yiddish | Hebrew script |

For the well-covered set (~50 locales spanning Western European, Slavic,
Baltic, Finno-Ugric, Turkic, Semitic, Indic, Southeast Asian, East Asian,
Ethiopic, Cherokee), further iteration would also be welcome — some
lists lean heavily on "first letter per alphabet letter" rather than
tailoring-sensitive word pairs.

## Collation tab — other pending work

* **`-u-kr` reorder codes** — editor UI for custom script reorder
  sequences (e.g. sort Cyrillic before Latin). Still not implemented.
* **Chinese (`zh`) tailoring** — all variants (`pinyin`, `stroke`,
  `zhuyin`, `unihan`) currently produce identical codepoint-order
  output. Needs investigation: is the Localize Han tailoring table
  loaded? Would benefit from a test against ICU reference output.

## Other tabs

* Dates & Times, Units, Messages, Calendars, Lists — all disabled in the
  header. Each needs its own tab-rendering LiveView modelled on
  `NumbersLive` / `CollationLive`.
