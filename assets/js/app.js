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

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
})

liveSocket.connect()
window.liveSocket = liveSocket
