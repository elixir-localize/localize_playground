import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

const Hooks = {}

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
