# Collation seed words

**Status:** planning, 2026-09-21

`Localize.Collation.Tailoring.supported_locales/0` exposes 116 tailored
locales. `CollationView.@seed_words` covers the ~50 languages where genuinely
representative words drawn from common vocabulary could be produced. The
remaining tailored locales fall back to the `en` seed list, which defeats the
point of showcasing their tailoring.

These still need properly curated 10-word seed lists written by someone with
native or working knowledge of each orthography. A synthetic list of "one word
per alphabet letter" is less useful than words that actually move around under
the tailoring.

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
Ethiopic, Cherokee), further iteration would also be welcome — some lists lean
heavily on "first letter per alphabet letter" rather than tailoring-sensitive
word pairs.
