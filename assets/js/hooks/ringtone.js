// The sound of a ringing call (video advice, phase 10), made with Web Audio,
// no audio file: data-tone="ring" for the one called (two short rings every
// three seconds), "ringback" for the caller (a soft tone every three
// seconds). Plays from mounted until the element goes away. Browsers allow
// sound after the visitor has interacted with the page, which the chat needs
// anyway.
const PATTERNS = {
  ring: [{at: 0, freq: 880, length: 0.35}, {at: 0.5, freq: 880, length: 0.35}],
  ringback: [{at: 0, freq: 440, length: 1.0}],
}

export const RingtoneHook = {
  mounted() {
    const pattern = PATTERNS[this.el.dataset.tone] || PATTERNS.ring
    try {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)()
    } catch (_e) {
      return
    }

    const play = () => {
      this.ctx.resume?.()
      const start = this.ctx.currentTime
      for (const {at, freq, length} of pattern) {
        const tone = this.ctx.createOscillator()
        const gain = this.ctx.createGain()
        tone.frequency.value = freq
        gain.gain.setValueAtTime(0.0001, start + at)
        gain.gain.exponentialRampToValueAtTime(0.15, start + at + 0.02)
        gain.gain.exponentialRampToValueAtTime(0.0001, start + at + length)
        tone.connect(gain).connect(this.ctx.destination)
        tone.start(start + at)
        tone.stop(start + at + length + 0.05)
      }
    }

    play()
    this.timer = setInterval(play, 3000)
  },

  destroyed() {
    clearInterval(this.timer)
    this.ctx?.close()
  },
}
