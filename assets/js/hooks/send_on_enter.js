// Chat inputs (the shop's chat and the sales desk): Enter sends, Shift+Enter
// and Ctrl+Enter make a new line, as in other chat apps. On touch screens
// Enter stays a new line: their keyboards have no Shift, and the form has a
// send button.
export const SendOnEnterHook = {
  mounted() {
    this.el.addEventListener("keydown", e => {
      if (e.key !== "Enter" || e.isComposing || e.altKey || e.metaKey) return
      if (window.matchMedia("(pointer: coarse)").matches) return

      if (e.shiftKey) return // the browser inserts the new line

      e.preventDefault()

      if (e.ctrlKey) {
        this.el.setRangeText("\n", this.el.selectionStart, this.el.selectionEnd, "end")
        this.el.dispatchEvent(new Event("input", {bubbles: true}))
      } else if (this.el.value.trim() !== "") {
        this.el.form.requestSubmit()
      }
    })
  }
}
