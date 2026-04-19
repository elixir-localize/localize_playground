import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

const Hooks = {}

// Persist a textarea's content in localStorage keyed by data-storage-key.
// On mount, if we have a stored value, push it up to the LiveView so the
// server state matches. Save on every input.
Hooks.PersistText = {
  mounted() {
    const key = this.el.getAttribute("data-storage-key")
    if (!key) return

    this._key = key

    try {
      const saved = localStorage.getItem(key)
      if (saved !== null && saved !== this.el.value) {
        this.el.value = saved
        this.pushEvent("persist_text", {value: saved})
      }
    } catch (e) { /* storage disabled */ }

    this._onInput = () => {
      try { localStorage.setItem(key, this.el.value) } catch (e) {}
    }
    this.el.addEventListener("input", this._onInput)
  },

  updated() {
    const key = this.el.getAttribute("data-storage-key")
    // If language changed, the storage key changes too. Load that
    // language's saved version (if any) and push it up.
    if (key && key !== this._key) {
      this._key = key
      try {
        const saved = localStorage.getItem(key)
        if (saved !== null && saved !== this.el.value) {
          this.el.value = saved
          this.pushEvent("persist_text", {value: saved})
        }
      } catch (e) {}
    }
  },

  destroyed() {
    if (this._onInput) this.el.removeEventListener("input", this._onInput)
  }
}

// Slide-out HexDocs panel. Intercepts clicks on `<a data-hexdocs>`
// anchors anywhere in the document, opens the panel with an iframe
// pointing at the link's href, and responds to Escape / backdrop /
// close-button clicks. A single instance lives in the root layout.
Hooks.HexDocsPanel = {
  mounted() {
    const panel = this.el
    const iframe = panel.querySelector("[data-hexdocs-frame]")
    const external = panel.querySelector("[data-hexdocs-external]")

    const open = (url, externalUrl) => {
      iframe.src = url
      external.href = externalUrl || url
      panel.classList.add("open")
      panel.setAttribute("aria-hidden", "false")
      document.body.style.overflow = "hidden"
    }

    const close = () => {
      panel.classList.remove("open")
      panel.setAttribute("aria-hidden", "true")
      document.body.style.overflow = ""
      // Clear iframe to stop any running media/scripts.
      setTimeout(() => { if (!panel.classList.contains("open")) iframe.src = "about:blank" }, 300)
    }

    // Global delegated listener for every hexdocs link.
    this._linkHandler = (ev) => {
      const link = ev.target.closest("a[data-hexdocs]")
      if (!link) return
      if (ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.button === 1) return
      ev.preventDefault()
      open(link.href, link.getAttribute("data-hexdocs-external-url") || link.href)
    }
    document.addEventListener("click", this._linkHandler)

    this._closeHandler = (ev) => {
      if (ev.target.closest("[data-hexdocs-close]")) close()
    }
    panel.addEventListener("click", this._closeHandler)

    this._escHandler = (ev) => { if (ev.key === "Escape") close() }
    document.addEventListener("keydown", this._escHandler)
  },

  destroyed() {
    document.removeEventListener("click", this._linkHandler)
    document.removeEventListener("keydown", this._escHandler)
  }
}

// Slide-out panel that displays a curated list of CLDR date/time format
// pattern codes. Opened by any element carrying `data-pattern-open` (the
// trigger button under the Custom pattern section on Dates & Times).
Hooks.PatternReferencePanel = {
  mounted() {
    const panel = this.el
    const open = () => {
      panel.classList.add("open")
      panel.setAttribute("aria-hidden", "false")
      document.body.style.overflow = "hidden"
    }
    const close = () => {
      panel.classList.remove("open")
      panel.setAttribute("aria-hidden", "true")
      document.body.style.overflow = ""
    }

    this._openHandler = (ev) => {
      if (ev.target.closest("[data-pattern-open]")) { ev.preventDefault(); open() }
    }
    document.addEventListener("click", this._openHandler)

    this._closeHandler = (ev) => {
      if (ev.target.closest("[data-pattern-close]")) close()
    }
    panel.addEventListener("click", this._closeHandler)

    this._escHandler = (ev) => { if (ev.key === "Escape") close() }
    document.addEventListener("keydown", this._escHandler)
  },
  destroyed() {
    document.removeEventListener("click", this._openHandler)
    document.removeEventListener("keydown", this._escHandler)
  }
}

// Keeps the URL query string in sync with data-style-group so the
// Referer header carries the selection across a UI locale change
// (which does a full POST → redirect → mount cycle).
Hooks.SyncStyleGroup = {
  mounted() { this._sync() },
  updated() { this._sync() },
  _sync() {
    const group = this.el.getAttribute("data-style-group")
    if (!group) return
    const url = new URL(window.location)
    if (url.searchParams.get("style_group") !== group) {
      url.searchParams.set("style_group", group)
      history.replaceState(history.state, "", url)
    }
  }
}

// MF2_EDITOR_INTEGRATION: hook lives in a sibling module
//
// The MF2Editor hook doesn't live in this file — it's in the
// `mf2_wasm_editor` package, served at /mf2_editor/mf2_editor.js
// and loaded via the `<script type="module">` tag emitted by
// Mf2WasmEditor.script_tags/1 (see root.html.heex). That module
// owns the textarea value + the highlighted <pre>, runs the
// tree-sitter-mf2 grammar in WASM, and applies syntax highlighting
// plus diagnostic squiggles on every keystroke — no server round
// trip.
//
// We don't call the hook directly here. Instead we merge its
// Hooks namespace into our own just before constructing the
// LiveSocket — search for the next MF2_EDITOR_INTEGRATION marker.

Hooks.MF2ReferencePanel = {
  mounted() {
    const panel = this.el
    const open = () => { panel.classList.add("open"); panel.setAttribute("aria-hidden", "false"); document.body.style.overflow = "hidden" }
    const close = () => { panel.classList.remove("open"); panel.setAttribute("aria-hidden", "true"); document.body.style.overflow = "" }

    this._openHandler = (ev) => { if (ev.target.closest("[data-mf2-open]")) { ev.preventDefault(); open() } }
    document.addEventListener("click", this._openHandler)

    this._closeHandler = (ev) => { if (ev.target.closest("[data-mf2-close]")) close() }
    panel.addEventListener("click", this._closeHandler)

    this._escHandler = (ev) => { if (ev.key === "Escape") close() }
    document.addEventListener("keydown", this._escHandler)
  },
  destroyed() {
    document.removeEventListener("click", this._openHandler)
    document.removeEventListener("keydown", this._escHandler)
  }
}

Hooks.CopyToClipboard = {
  mounted() {
    const button = this.el.querySelector("[data-copy-target]")
    if (!button) return

    button.addEventListener("click", async () => {
      const targetSel = button.getAttribute("data-copy-target")
      const target = this.el.querySelector(targetSel)
      if (!target) return
      const text = target.innerText

      try {
        await navigator.clipboard.writeText(text)
      } catch (e) {
        // Fallback for older browsers / insecure contexts
        const ta = document.createElement("textarea")
        ta.value = text
        document.body.appendChild(ta)
        ta.select()
        document.execCommand("copy")
        document.body.removeChild(ta)
      }

      const label = button.querySelector(".lp-copy-label")
      const original = label ? label.textContent : null
      if (label) {
        label.textContent = "Copied"
        button.classList.add("copied")
        setTimeout(() => {
          label.textContent = original
          button.classList.remove("copied")
        }, 1200)
      }
    })
  }
}

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content")

// MF2_EDITOR_INTEGRATION: merge the hook into LiveSocket
//
// /mf2_editor/mf2_editor.js is an ES module that evaluates before
// this file (both deferred; the MF2 script tag is earlier in the
// root layout). Its side-effect registers MF2Editor onto
// `window.Mf2WasmEditor.Hooks`. We merge that namespace into our
// own Hooks object so LiveView sees `MF2Editor` alongside the
// playground's own hooks. Optional-chaining (`?.`) guards against
// the module failing to load — the rest of the app still starts.
//
// Guide: https://hexdocs.pm/mf2_wasm_editor/wiring.html#3-merge-the-hook-into-your-livesocket
const AllHooks = Object.assign({}, Hooks, window.Mf2WasmEditor?.Hooks || {})

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: AllHooks,
  params: {_csrf_token: csrfToken}
})

liveSocket.connect()
window.liveSocket = liveSocket
