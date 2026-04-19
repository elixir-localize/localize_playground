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

### Local ecosystem checkouts

The playground depends on `localize_mf2_treesitter` and `mf2_wasm_editor`, both published on hex. If you have sibling checkouts of those packages and want mix to use them directly (for live iteration against grammar or hook changes), export `LOCALIZE_PATH_DEPS=1` before running mix commands:

```bash
export LOCALIZE_PATH_DEPS=1
mix deps.get
iex -S mix phx.server
```

Without the env var, mix pulls the hex versions pinned in `mix.exs`. The Docker build (`fly deploy`) never sets `LOCALIZE_PATH_DEPS`, so production always uses hex.

## MF2 editor integration

The Messages tab uses [`mf2_wasm_editor`](https://hex.pm/packages/mf2_wasm_editor) — a drop-in Phoenix LiveView hook that runs the ICU MessageFormat 2 tree-sitter grammar directly in the browser. This playground is meant to double as a reference integration: everything you'd need to do to wire the editor into your own Phoenix app is done here, once, visibly.

**Find every integration point by grepping for `MF2_EDITOR_INTEGRATION`:**

```bash
grep -rn MF2_EDITOR_INTEGRATION .
```

Each hit has a header comment with a short label and a link to the relevant section of the `mf2_wasm_editor` guides. The eight touchpoints are:

| File | Label | What it does |
| --- | --- | --- |
| `mix.exs` | dependency declaration | Hex dep with a path-dep toggle for local iteration. |
| `lib/localize_playground_web/endpoint.ex` | serve the hook's static assets | `Plug.Static` exposing the WASM runtime + hook at `/mf2_editor`. |
| `lib/localize_playground_web/endpoint.ex` | serve the editor themes | `Plug.Static` exposing the 30 bundled colour themes at `/mf2_editor/themes`. |
| `lib/localize_playground_web/components/layouts/root.html.heex` | token theme stylesheet | `<link>` to `monokai.css` from the bundled themes. |
| `lib/localize_playground_web/components/layouts/root.html.heex` | script tag | `{raw(Mf2WasmEditor.script_tags())}` emitting the ES-module script; **must come before `app.js`**. |
| `assets/js/app.js` | hook lives in a sibling module | Note explaining the hook is loaded separately. |
| `assets/js/app.js` | merge the hook into LiveSocket | `Object.assign({}, Hooks, window.Mf2WasmEditor?.Hooks \|\| {})`. |
| `lib/localize_playground_web/live/messages_live.ex` | the hook element | The `<div phx-hook="MF2Editor">` markup that binds the hook to a pre/textarea pair. |
| `lib/localize_playground_web/live/messages_live.ex` | server-render the initial paint | `Localize.Message.to_html/2` paints `@message_html` once at mount. |
| `lib/localize_playground_web/live/messages_live.ex` | hard-replace the textarea value | `push_event("mf2:set_message", …)` for example-loading. |
| `lib/localize_playground_web/live/messages_live.ex` | format-on-blur via mf2:canonical | `push_event("mf2:canonical", …)` with the server's canonical form. |
| `lib/localize_playground_web/live/messages_live.ex` | gate the formatter on client-side validity | NimbleParsec parse check that suppresses the formatter mid-edit. |
| `lib/localize_playground_web/live/messages_live.ex` | keyboard-shortcut reference card | A floating panel mirroring the hook's keybindings. |
| `priv/static/assets/app.css` | editor overlay CSS | Font-metric pinning for the transparent-textarea-over-highlighted-pre overlay. |
| `priv/static/assets/app.css` | token colour rules (note: not here) | Deliberate pointer: per-token colours come from the theme stylesheet. |

For the full wiring recipe — including the "why" behind each step and the sharp edges that will silently break the editor if missed — see [`mf2_wasm_editor`'s wiring guide](https://hexdocs.pm/mf2_wasm_editor/wiring.html).

## Architecture

* Phoenix 1.7 + LiveView 1.0 + Bandit
* Localize added via path dep: `{:localize, path: "../localize"}`
* All state lives in `LocalizePlaygroundWeb.PageLive`
* Rendering is split into `LocalizePlaygroundWeb.NumbersLive` (HEEx-only, no state)
* Formatting helpers wrapping `Localize.Number` live in `LocalizePlaygroundWeb.NumberView`
* Styling is plain CSS in `priv/static/assets/app.css`, based on the tokens used by `Color.Palette.Visualizer`
