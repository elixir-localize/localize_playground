# TODO

## Open

* [ ] **Seed word lists for minority and indigenous languages** — 27 tailored locales still fall back to the `en` seed list; each needs a curated 10-word list that moves under its tailoring. The locale table is in [plans/collation-seed-words.md](plans/collation-seed-words.md).
* [ ] **Better seed lists for the covered locales** — some of the ~50 existing lists lean on "first letter per alphabet letter" rather than tailoring-sensitive word pairs.
* [ ] **Remaining tabs** — Dates & Times, Units, Messages, Calendars and Lists are disabled in the header; each needs its own tab-rendering LiveView modelled on `NumbersLive` and `CollationLive`.

## Done

* [x] **`-u-kr` reorder-code editor and Han tailoring** — both working as of Localize 0.12.
