// The browser side of a call (video advice, phase 10, docs/video-design.md):
// microphone and camera, the WebRTC connection to the shop's media relay
// (Mercator.Consulting.Calls.Room), and the mute and camera buttons.
//
// Put phx-hook="Call" and phx-update="ignore" on a container with a unique id
// (see MercatorWeb.CallComponents.call_media/1); data-video="true" starts with
// the camera on. Once microphone (and camera) are ready, the hook pushes
// "call_media_ready"; the LiveView joins the room, which makes the offer.
// The connection has three channels in a fixed order, audio, camera and
// screen: this side answers once and only replaces tracks afterwards.
//
// From the LiveView: "call:signal" with {type: "offer" | "candidate" | "peer" |
// "state", ...}. To the LiveView: "call_signal" (answer, candidates),
// "call_media_ready", "call_media_error" ({name}) and "call_video" (the
// camera was turned on, for the call's history).
export const CallHook = {
  mounted() {
    this.pc = null
    this.local = {audio: null, camera: null}
    // signals are handled one after the other: candidates may arrive while
    // the offer is still being answered
    this.queue = Promise.resolve()
    this.handleEvent("call:signal", (message) => {
      this.queue = this.queue.then(() => this.signal(message)).catch((error) => console.error(error))
    })

    // leaving the page ends the call: ask first
    this.beforeUnload = (e) => { e.preventDefault(); e.returnValue = "" }
    window.addEventListener("beforeunload", this.beforeUnload)

    this.button("mute")?.addEventListener("click", () => this.toggleMute())
    this.button("camera")?.addEventListener("click", () => this.toggleCamera())

    this.start(this.el.dataset.video === "true")
  },

  destroyed() {
    window.removeEventListener("beforeunload", this.beforeUnload)
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
    const [audio, camera] = this.transceivers()
    for (const transceiver of pc.getTransceivers()) transceiver.direction = "sendrecv"
    await audio.sender.replaceTrack(this.local.audio)
    await camera.sender.replaceTrack(this.local.camera)

    const answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    this.pushEvent("call_signal", {type: "answer", sdp: answer.sdp})
  },

  // the channels in the order of the offer: audio, camera, screen
  transceivers() {
    return [...this.pc.getTransceivers()].sort((a, b) => Number(a.mid) - Number(b.mid))
  },

  toggleMute() {
    const track = this.local.audio
    if (!track) return
    track.enabled = !track.enabled
    this.button("mute").classList.toggle("btn-error", !track.enabled)
    this.button("mute").setAttribute("aria-pressed", String(!track.enabled))
  },

  async toggleCamera() {
    const [, camera] = this.pc ? this.transceivers() : []

    if (this.local.camera) {
      this.local.camera.stop()
      this.local.camera = null
      await camera?.sender.replaceTrack(null)
    } else {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({video: true})
        this.local.camera = stream.getVideoTracks()[0]
        await camera?.sender.replaceTrack(this.local.camera)
        this.pushEvent("call_video", {})
      } catch (_error) {
        return
      }
    }

    this.showLocal()
  },

  showLocal() {
    const video = this.el.querySelector("[data-local-camera]")
    video.srcObject = this.local.camera ? new MediaStream([this.local.camera]) : null
    video.classList.toggle("hidden", !this.local.camera)
    this.button("camera")?.setAttribute("aria-pressed", String(Boolean(this.local.camera)))
    this.button("camera")?.classList.toggle("btn-active", Boolean(this.local.camera))
  },

  // a remote track shows while media arrives (a camera that is off sends nothing)
  showRemote(mid, track) {
    const slot = {"0": "audio", "1": "camera", "2": "screen"}[mid]
    const element = this.el.querySelector(`[data-remote-${slot}]`)
    if (!element) return

    element.srcObject = new MediaStream([track])
    const visible = () => element.classList.toggle("hidden", track.muted)
    track.onmute = visible
    track.onunmute = visible
    if (slot !== "audio") visible()
    element.play?.().catch(() => {})
  },

  setPeer(state) {
    this.el.dataset.peer = state
    if (state === "left") this.setStatus("peer-left")
  },

  setStatus(state) {
    const status = this.el.querySelector("[data-call-status]")
    if (!status) return
    const text = status.dataset[`text${state.replace(/(^|-)(\w)/g, (_m, _d, c) => c.toUpperCase())}`]
    status.textContent = text || ""
    status.classList.toggle("hidden", !text)
  },

  button(name) {
    return this.el.querySelector(`[data-call-${name}]`)
  },
}
