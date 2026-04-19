defmodule LocalizePlaygroundWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :localize_playground

  @session_options [
    store: :cookie,
    key: "_localize_playground_key",
    signing_salt: "Uh4qO3Rn",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]
  )

  plug(Plug.Static,
    at: "/",
    from: :localize_playground,
    gzip: false,
    only: LocalizePlaygroundWeb.static_paths()
  )

  # MF2_EDITOR_INTEGRATION: serve the hook's static assets
  #
  # The mf2_wasm_editor package ships its JS hook, the web-tree-sitter
  # runtime (`web-tree-sitter.js` + `.wasm`), the compiled MF2 grammar
  # (`tree-sitter-mf2.wasm`), and the `highlights.scm` query — all
  # under its own `priv/static/`. `Plug.Static` exposes the lot at
  # `/mf2_editor`, which is the default base URL
  # `Mf2WasmEditor.script_tags/1` emits and the hook's runtime code
  # fetches from.
  #
  # `:only` is set from `Mf2WasmEditor.static_paths()` so nothing
  # else in the package's priv dir is accidentally exposed.
  #
  # Guide: https://hexdocs.pm/mf2_wasm_editor/wiring.html#1-serve-the-static-assets
  plug(Plug.Static,
    at: "/mf2_editor",
    from: {:mf2_wasm_editor, "priv/static"},
    gzip: false,
    only: Mf2WasmEditor.static_paths()
  )

  # MF2_EDITOR_INTEGRATION: serve the editor themes
  #
  # `mf2_wasm_editor` ships 30 drop-in colour themes under
  # `priv/themes/`. They target the tree-sitter capture class names
  # (`.mf2-variable`, `.mf2-punctuation-bracket`, etc.) that the
  # hook emits, so one stylesheet styles both the live editor and
  # `Localize.Message.to_html/2` server-rendered output. We serve
  # them on a separate prefix so the root layout can link one
  # (`monokai` in our case — see `root.html.heex`).
  #
  # Drop this block if you prefer to style the tokens yourself or
  # pick a theme name different from the ~30 available.
  #
  # Guide: https://hexdocs.pm/mf2_wasm_editor/features.html#themes
  plug(Plug.Static,
    at: "/mf2_editor/themes",
    from: {:mf2_wasm_editor, "priv/themes"},
    gzip: true,
    only:
      ~w(abap.css algol.css algol_nu.css arduino.css autumn.css borland.css
         bw.css colorful.css default.css emacs.css friendly.css fruity.css
         igor.css lovelace.css manni.css monokai.css murphy.css native.css
         paraiso_dark.css paraiso_light.css pastie.css perldoc.css
         rainbow_dash.css rrt.css samba.css tango.css trac.css vim.css
         vs.css xcode.css)
  )

  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(LocalizePlaygroundWeb.Router)
end
