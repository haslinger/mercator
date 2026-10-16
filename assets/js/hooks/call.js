// The browser side of a call (video advice, phase 10, docs/video-design.md):
// microphone and camera, the WebRTC connection to the shop's media relay
// (Mercator.Consulting.Calls.Room), screen sharing, device choice, the
// speaking indicator and the full-screen view.
//
// Put phx-hook="Call" and phx-update="ignore" on a container with a unique id
// (see MercatorWeb.CallComponents.call_media/1); data-video="true" starts with
// the camera on. Once microphone (and camera) are ready, the hook pushes
// "call_media_ready"; the LiveView joins the room, which makes the offer.
// The connection has three channels in a fixed order, audio, camera and
// screen: this side answers once and only replaces tracks afterwards.
//
// From the LiveView: "call:signal" with {type: "offer" | "candidate" | "peer" |
// "state" | "screen", ...}. To the LiveView: "call_signal" (answer,
// candidates), "call_media_ready", "call_media_error" ({name}), "call_video"
// (the camera was turned on) and "call_screen" ({on}) for a screen share.
const SPEAKING_LEVEL = 0.04

export const CallHook = {
  mounted() {
    this.pc = null
    this.local = {audio: null, camera: null, screen: null}
    this.cameraId = null
    this.remoteScreenOn = false
    this.meters = []
    // signals are handled one after the other: candidates may arrive while
    // the offer is still being answered
    this.queue = Promise.resolve()
    this.handleEvent("call:signal", (message) => {
      this.queue = this.queue.then(() => this.signal(message)).catch((error) => console.error(error))
    })

    // leaving the page ends the call: ask first
    this.beforeUnload = (e) => { e.preventDefault(); e.returnValue = "" }
    window.addEventListener("beforeunload", this.beforeUnload)

    this.on("mute", () => this.toggleMute())
    this.on("camera", () => this.toggleCamera())
    this.on("screen", () => this.toggleScreen())
    this.on("settings", () => this.toggleSettings())
    this.on("fullscreen", () => this.toggleFullscreen())
    this.el.querySelector("[data-call-mic]")?.addEventListener("change", (e) => this.useMicrophone(e.target.value))
    this.el.querySelector("[data-call-cam]")?.addEventListener("change", (e) => this.useCamera(e.target.value))
    this.onDeviceChange = () => this.fillDevices()
    navigator.mediaDevices?.addEventListener?.("devicechange", this.onDeviceChange)

    // not every browser can share a screen or go full screen (e.g. phones)
    if (!navigator.mediaDevices?.getDisplayMedia) this.button("screen")?.classList.add("hidden")
    if (!document.fullscreenEnabled) this.button("fullscreen")?.classList.add("hidden")

    this.start(this.el.dataset.video === "true")
  },

  destroyed() {
    window.removeEventListener("beforeunload", this.beforeUnload)
    navigator.mediaDevices?.removeEventListener?.("devicechange", this.onDeviceChange)
    for (const meter of this.meters) clearInterval(meter)
    this.audioContext?.close()
    this.pc?.close()
    for (const track of Object.values(this.local)) track?.stop()
  },

  async start(withVideo) {
    this.setStatus("preparing")

    try {
      const stream = await navigator.mediaDevices.getUserMedia({audio: true, video: withVideo})
      this.local.audio = stream.getAudioTracks()[0] || null
      this.local.camera = stream.getVideoTracks()[0] || null
      this.showLocal()
      this.showMicrophone()
      this.meter(this.local.audio, this.button("mute"))
      this.fillDevices()
      this.pushEvent("call_media_ready", {})
    } catch (error) {
      // no microphone, or the permission was refused
      this.pushEvent("call_media_error", {name: error.name || "Error"})
    }
  },

  async signal(message) {
    switch (message.type) {
      case "offer": return this.answer(message)
      case "candidate": return this.pc?.addIceCandidate(message.candidate)
      case "peer": return this.setPeer(message.state)
      case "screen": return this.remoteScreen(message.state === "on")
      default: return null
    }
  },

  async answer(offer) {
    this.pc?.close()
    const pc = new RTCPeerConnection()
    this.pc = pc

    pc.onicecandidate = (e) => {
      if (e.candidate) this.pushEvent("call_signal", {type: "candidate", candidate: e.candidate.toJSON()})
    }
    pc.ontrack = (e) => this.showRemote(e.transceiver.mid, e.track)
    pc.onconnectionstatechange = () => this.setStatus(pc.connectionState)

    await pc.setRemoteDescription(offer)
    const [audio, camera, screen] = this.transceivers()
    for (const transceiver of pc.getTransceivers()) transceiver.direction = "sendrecv"
    await audio.sender.replaceTrack(this.local.audio)
    await camera.sender.replaceTrack(this.local.camera)
    await screen.sender.replaceTrack(this.local.screen)

    const answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    this.pushEvent("call_signal", {type: "answer", sdp: answer.sdp})
  },

  // the channels in the order of the offer: audio, camera, screen
  transceivers() {
    return this.pc ? [...this.pc.getTransceivers()].sort((a, b) => Number(a.mid) - Number(b.mid)) : []
  },

  async replace(slot, track) {
    const index = {audio: 0, camera: 1, screen: 2}[slot]
    await this.transceivers()[index]?.sender.replaceTrack(track)
  },

  // --- microphone and camera ---

  toggleMute() {
    const track = this.local.audio
    if (!track) return
    track.enabled = !track.enabled
    this.showMicrophone()
  },

  // green while the microphone is on, red while muted
  showMicrophone() {
    const on = Boolean(this.local.audio?.enabled)
    this.setPressed("mute", !on, "btn-error")
    this.button("mute")?.classList.toggle("btn-success", on)
  },

  async toggleCamera() {
    if (this.local.camera) {
      this.local.camera.stop()
      this.local.camera = null
      await this.replace("camera", null)
    } else {
      try {
        const video = this.cameraId ? {deviceId: {exact: this.cameraId}} : true
        const stream = await navigator.mediaDevices.getUserMedia({video})
        this.local.camera = stream.getVideoTracks()[0]
        await this.replace("camera", this.local.camera)
        this.pushEvent("call_video", {})
      } catch (_error) {
        return
      }
    }

    this.showLocal()
  },

  async useMicrophone(deviceId) {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({audio: {deviceId: {exact: deviceId}}})
      const track = stream.getAudioTracks()[0]
      // keep the mute state
      track.enabled = this.local.audio ? this.local.audio.enabled : true
      this.local.audio?.stop()
      this.local.audio = track
      await this.replace("audio", track)
      this.meter(track, this.button("mute"))
    } catch (_error) {
      this.fillDevices()
    }
  },

  async useCamera(deviceId) {
    this.cameraId = deviceId
    if (!this.local.camera) return

    try {
      const stream = await navigator.mediaDevices.getUserMedia({video: {deviceId: {exact: deviceId}}})
      this.local.camera.stop()
      this.local.camera = stream.getVideoTracks()[0]
      await this.replace("camera", this.local.camera)
      this.showLocal()
    } catch (_error) {
      this.fillDevices()
    }
  },

  toggleSettings() {
    const panel = this.el.querySelector("[data-call-devices]")
    panel?.classList.toggle("hidden")
    this.setPressed("settings", !panel?.classList.contains("hidden"), "btn-active")
    this.fillDevices()
  },

  // the device lists, with the devices in use selected (labels appear once
  // the browser has the permission)
  async fillDevices() {
    if (!navigator.mediaDevices?.enumerateDevices) return
    const devices = await navigator.mediaDevices.enumerateDevices()
    const fill = (select, kind, current, fallback) => {
      if (!select) return
      const options = devices.filter((d) => d.kind === kind)
      select.replaceChildren(...options.map((device, i) => {
        const option = document.createElement("option")
        option.value = device.deviceId
        option.textContent = device.label || `${fallback} ${i + 1}`
        option.selected = device.deviceId === current
        return option
      }))
    }

    fill(this.el.querySelector("[data-call-mic]"), "audioinput",
      this.local.audio?.getSettings().deviceId, this.el.dataset.textMicrophone || "Microphone")
    fill(this.el.querySelector("[data-call-cam]"), "videoinput",
      this.local.camera?.getSettings().deviceId || this.cameraId, this.el.dataset.textCamera || "Camera")
  },

  // --- screen sharing: one at a time, the newest wins (#143) ---

  async toggleScreen() {
    if (this.local.screen) return this.stopScreen()

    try {
      const stream = await navigator.mediaDevices.getDisplayMedia({video: true, audio: false})
      this.local.screen = stream.getVideoTracks()[0]
      // the browser's own "stop sharing" button
      this.local.screen.onended = () => this.stopScreen()
      await this.replace("screen", this.local.screen)
      this.setPressed("screen", true, "btn-success")
      this.pushEvent("call_screen", {on: true})
    } catch (_error) {
      // the choice was cancelled
    }
  },

  async stopScreen() {
    if (!this.local.screen) return
    this.local.screen.onended = null
    this.local.screen.stop()
    this.local.screen = null
    await this.replace("screen", null)
    this.setPressed("screen", false, "btn-success")
    this.pushEvent("call_screen", {on: false})
  },

  async remoteScreen(on) {
    this.remoteScreenOn = on
    if (on) await this.stopScreen()
    this.refreshScreen?.()
  },

  // --- full screen ---

  toggleFullscreen() {
    const box = this.el.querySelector("[data-call-box]")
    if (document.fullscreenElement) document.exitFullscreen()
    else box?.requestFullscreen?.().catch(() => {})
  },

  // --- what is shown ---

  showLocal() {
    const video = this.el.querySelector("[data-local-camera]")
    video.srcObject = this.local.camera ? new MediaStream([this.local.camera]) : null
    video.classList.toggle("hidden", !this.local.camera)
    this.setPressed("camera", Boolean(this.local.camera), "btn-success")
  },

  // a remote track shows while media arrives (a camera that is off sends nothing)
  showRemote(mid, track) {
    const slot = {"0": "audio", "1": "camera", "2": "screen"}[mid]
    const element = this.el.querySelector(`[data-remote-${slot}]`)
    if (!element) return

    element.srcObject = new MediaStream([track])
    element.play?.().catch(() => {})

    if (slot === "audio") return this.meter(track, this.el.querySelector("[data-call-box]"))

    // a shared screen also hides when the other stops sharing, before the
    // media stops arriving
    const visible = () =>
      element.classList.toggle("hidden", track.muted || (slot === "screen" && !this.remoteScreenOn))
    track.onmute = visible
    track.onunmute = visible
    if (slot === "screen") this.refreshScreen = visible
    visible()
  },

  // the speaking indicator: a ring around `target` while the track's level is up
  meter(track, target) {
    if (!track || !target || !window.AudioContext) return
    this.audioContext ||= new AudioContext()
    const analyser = this.audioContext.createAnalyser()
    analyser.fftSize = 512
    this.audioContext.createMediaStreamSource(new MediaStream([track])).connect(analyser)
    const samples = new Uint8Array(analyser.fftSize)

    const timer = setInterval(() => {
      if (track.readyState === "ended") return clearInterval(timer)
      analyser.getByteTimeDomainData(samples)
      let sum = 0
      for (const sample of samples) sum += ((sample - 128) / 128) ** 2
      const speaking = track.enabled && Math.sqrt(sum / samples.length) > SPEAKING_LEVEL
      target.classList.toggle("ring-2", speaking)
      target.classList.toggle("ring-success", speaking)
    }, 150)

    this.meters.push(timer)
  },

  setPeer(state) {
    this.el.dataset.peer = state
    if (state === "left") { this.remoteScreen(false); this.setStatus("peer-left") }
  },

  setStatus(state) {
    const status = this.el.querySelector("[data-call-status]")
    if (!status) return
    const text = status.dataset[`text${state.replace(/(^|-)(\w)/g, (_m, _d, c) => c.toUpperCase())}`]
    status.textContent = text || ""
    status.classList.toggle("hidden", !text)
  },

  setPressed(name, pressed, className) {
    const button = this.button(name)
    if (!button) return
    button.classList.toggle(className, pressed)
    button.setAttribute("aria-pressed", String(pressed))
  },

  on(name, handler) {
    this.button(name)?.addEventListener("click", handler)
  },

  button(name) {
    return this.el.querySelector(`[data-call-${name}]`)
  },
}
