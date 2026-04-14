# Localize Playground

An interactive web UI for exploring what CLDR has to offer, as implemented by the [Localize](../localize) Elixir library. Modelled visually on the [Color](../color) palette visualizer.

The first tab, **Numbers**, lets you select any CLDR locale, pick a format family (decimal, currency, percent, compact, RBNF, range, approximately, custom pattern), tweak options such as fractional digits and rounding mode, and see the formatted result, the resolved CLDR pattern, and the parsed pattern metadata, all updating live as you type.

Future tabs: Dates & Times, Units, Messages, Calendars, Lists, Collation.

## Running

```bash
mix deps.get
mix esbuild.install --if-missing
mix esbuild default
iex -S mix phx.server
```

Then open <http://localhost:5001>.

During development, `mix phx.server` runs an esbuild watcher that rebuilds `priv/static/assets/app.js` when `assets/js/app.js` changes.

## Architecture

* Phoenix 1.7 + LiveView 1.0 + Bandit
* Localize added via path dep: `{:localize, path: "../localize"}`
* All state lives in `LocalizePlaygroundWeb.PageLive`
* Rendering is split into `LocalizePlaygroundWeb.NumbersLive` (HEEx-only, no state)
* Formatting helpers wrapping `Localize.Number` live in `LocalizePlaygroundWeb.NumberView`
* Styling is plain CSS in `priv/static/assets/app.css`, based on the tokens used by `Color.Palette.Visualizer`
