// Markdown editor (#78): OverType (MIT, self-hosted in priv/static/overtype,
// taken over from the pan project) shows the formatting inline and has a
// toolbar. It is only loaded on pages that use it. The hook replaces the
// server-rendered textarea by the editor, whose own textarea keeps the name
// and id, so phx-change and submits work unchanged. Without JavaScript the
// plain textarea stays.
let overTypeLoading = null

function loadOverType() {
  if (!overTypeLoading) {
    overTypeLoading = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = "/overtype/overtype.min.js"
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })
  }
  return overTypeLoading
}

// Colours from the active DaisyUI theme, so the editor follows light/dark mode
const theme = {
  name: "mercator",
  colors: {
    bgPrimary: "var(--color-base-100)",
    bgSecondary: "var(--color-base-200)",
    text: "var(--color-base-content)",
    textPrimary: "var(--color-base-content)",
    textSecondary: "var(--color-neutral)",
    h1: "var(--color-primary)",
    h2: "var(--color-primary)",
    h3: "var(--color-secondary)",
    strong: "var(--color-base-content)",
    em: "var(--color-base-content)",
    del: "var(--color-neutral)",
    link: "var(--color-primary)",
    code: "var(--color-base-content)",
    codeBg: "var(--color-base-200)",
    blockquote: "var(--color-neutral)",
    hr: "var(--color-base-300)",
    syntaxMarker: "color-mix(in oklab, var(--color-base-content) 45%, transparent)",
    syntax: "color-mix(in oklab, var(--color-base-content) 45%, transparent)",
    cursor: "var(--color-primary)",
    selection: "color-mix(in oklab, var(--color-primary) 25%, transparent)",
    listMarker: "var(--color-primary)",
    toolbarBg: "var(--color-base-200)",
    toolbarIcon: "var(--color-base-content)",
    toolbarHover: "var(--color-base-300)",
    toolbarActive: "var(--color-base-300)",
    border: "var(--color-base-300)",
  },
}

export const MarkdownEditor = {
  mounted() {
    const textarea = this.el.querySelector("textarea")

    loadOverType().then(() => {
      const editorEl = document.createElement("div")
      this.el.replaceChild(editorEl, textarea)

      ;[this.editor] = new window.OverType(editorEl, {
        value: textarea.value,
        toolbar: true,
        autoResize: true,
        minHeight: textarea.dataset.minHeight || "160px",
        placeholder: textarea.placeholder,
        theme,
        textareaProps: {name: textarea.name, id: textarea.id},
      })
    })
  },

  destroyed() {
    if (this.editor) this.editor.destroy()
  },
}
