# Video advice (phase 10) – design

Status: **agreed 2026-10-16** (#139–#149). #139 phase 10 is self-hosted audio, video
and screen sharing with Elixir WebRTC (`ex_webrtc`), inside the shop, instead of an
external video service; #144 two participants (a prototype); #147 a published UDP
range for a container with a fixed IP; the other questions as recommended (section 10).

## 1. Goals

- A consultant and a customer **talk, see each other and share a screen** inside an
  advice conversation (#100), without a second tool, account or link.
- The call belongs to the conversation: the same people may join, the chat stays
  usable during the call, and the call appears in the conversation's history.
- **Everything stays in the Elixir ecosystem**: the media relay runs in the Mercator
  release itself, supervised like any other process. No separate media server.
- A **showcase**: chat, video and screen sharing in one Phoenix app, with the call's
  statistics in the LiveDashboard (`/admin/system`).

Not goals: webinars or large meetings, recording, phone dial-in, mobile apps.

## 2. What the Rails app did

The Rails app linked to an external WebRTC service (palava) from the conversation.
There was no integration beyond the link.

## 3. Building blocks

All by Software Mansion, Apache-2.0:

| Package | Use here |
|---|---|
| `ex_webrtc` (0.17) | W3C WebRTC API in Elixir: one `ExWebRTC.PeerConnection` per participant on the server |
| `ex_webrtc_dashboard` | WebRTC statistics as a LiveDashboard page |
| Nexus (`elixir-webrtc/apps`) | Example SFU for video conferences in Phoenix; blueprint for the room process, not a dependency |
| `live_ex_webrtc` | LiveView components for one-way publish/play; read for its JS hook, probably not used as is (we need two-way calls in an existing LiveView) |
| `rel` | TURN/STUN server in Elixir; early stage, UDP only (#146) |

**Membrane** is not needed: an SFU forwards encrypted media packets without decoding
them, which `ex_webrtc` does alone. Membrane would come in for processing (recording,
mixing, transcription); its WebRTC plugin is built on `ex_webrtc`, so that stays open.
**Fishjam** is not used: its open-source server has not been maintained since 2024.

## 4. Architecture

```
Browser (customer)                 Mercator release                     Browser (consultant)
ChatLive + JS hook "Call"  ◀─LV─▶  Consulting.Calls.Room  ◀─LV─▶  DeskLive + JS hook "Call"
RTCPeerConnection          ◀─UDP─▶ PeerConnection per      ◀─UDP─▶ RTCPeerConnection
                                   participant (SFU)
```

- **SFU, not peer-to-peer.** Each browser connects to the server only. The server
  forwards every track to the other participant. Peer-to-peer would be simpler for
  two people, but the media would bypass Elixir entirely (no showcase, no statistics,
  and the customer's IP address would be shown to the consultant's browser and vice
  versa). The room is written for two participants (#144); forwarding to more is the
  same loop, so a third participant stays possible later.
- **Room process:** `Mercator.Consulting.Calls.Room`, a GenServer per active call,
  registered by conversation id (`Registry`) under a `DynamicSupervisor`. It owns one
  `PeerConnection` per participant, maps each incoming track to outgoing tracks on the
  other, forwards RTP packets and passes keyframe requests (PLI) back to the sender.
  For a newly connected participant the room asks the sender for a keyframe with the
  next video packet, so the picture appears at once (before the first packet the
  sender's stream is not known yet). The room ends when the last
  participant leaves, or after a grace period when only one is left.
- **Signaling through the existing LiveViews.** SDP offers and answers and ICE
  candidates travel as LiveView events (`push_event` / `this.pushEvent`) between the
  browser's hook and the LiveView, which passes them to the room. No extra
  Phoenix Channel or socket: authentication, the actor and the conversation are already
  there.
- **The customer side lives in `ChatLive`,** which is rendered from the root layout and
  survives live navigation. So **the call keeps running while the customer browses
  the shop**, and the consultant can show a product page meanwhile. A full page load
  (sign-in, payment redirect, a plain link) ends the call; the hook warns before
  leaving the page during a call.
- **The consultant side lives in `DeskLive`**, in a floating call card that stays
  while the consultant switches conversations (#150), so the media keeps running;
  a link leads back to the call's conversation. A consultant is in one call at a time.
- **No renegotiation:** each connection has three channels in a fixed order, audio,
  camera and screen, negotiated once when the participant joins; the server always
  makes the offer. Turning the camera or a screen share on or off only replaces the
  track in the browser (`replaceTrack`), so the offer/answer round never repeats.
  *(Simpler than the perfect negotiation planned first, possible because a call has
  exactly two participants, #144.)*
- **Domain:** calls are part of `Mercator.Consulting`; no new domain.

## 5. Calls in the conversation

- **Who:** the customer of the conversation and the consultant who has taken it: two
  participants (#144). Checked by an Ash policy before the
  LiveView may join the room; the room accepts only LiveView processes it was told
  about. Visitors without an account: #140.
- **Starting:** the consultant starts a call ("Anrufen": audio, or with video); the
  customer's chat panel rings with "Annehmen" / "Ablehnen". The customer can ask for a
  call with one button, which rings at the desk (#141).
- **Media:** audio always; camera per side, the customer's camera off by default
  (#142); screen sharing from either side, one share at a time (#143).
- **Controls:** mute, camera on/off, share screen, choose microphone and camera,
  hang up; an indicator for who is speaking; a full-screen view for a shared screen.
  A second consultant who wants to help takes over the conversation (as today) and
  calls again.
- **History:** a `Call` resource (conversation, who started it, participants, started
  and ended at, whether video and screen sharing were used, how it ended) plus a system
  message in the chat: "Videoanruf, 14:05–14:20". Useful for the consultant, for
  statistics and for diagnosing failed calls (#148).
- **No recording** (#145). Media is encrypted on the way (DTLS-SRTP, mandatory in
  WebRTC); the server decrypts and re-encrypts it to forward it, so the privacy notice
  says calls go through the shop's server and are not recorded (#149).

## 6. Networking and deployment

- **HTTPS** is required for camera and microphone (except on `localhost`). The demo has
  it; for testing from other devices on the LAN in development, `mix phx.gen.cert`.
- **UDP ports (#147):** media does not go through the reverse proxy. The app listens
  on a fixed UDP range (`ice_port_range`, e.g. 50000–50049, set by an environment
  variable). `docker-compose.yml` publishes it with **the same numbers on host and
  container** (`50000-50049:50000-50049/udp`), because the app announces its container
  ports to the browsers. The router forwards the range to the server. Signaling stays
  on HTTPS/WebSocket through the proxy.
- **Fixed container IP (#147):** the app gets a fixed address on its own Compose
  network (a fixed `subnet` and `ipv4_address`, e.g. `172.30.0.10`), so the firewall
  can allow the range for that one container only. Note: Docker writes its own
  iptables rules for published ports, and they take effect before ufw's, so a published
  range is open even without a ufw rule. To make ufw decide, its rules have to be tied
  into Docker's `DOCKER-USER` chain (the ufw-docker approach); then
  `ufw route allow proto udp from any to 172.30.0.10 port 50000:50049 comment mercator-calling` is the one rule
  needed. The demo server already has the [ufw-docker](https://github.com/chaifeng/ufw-docker)
  rules, so step 5 is tested with that setup. The operating guide describes both the
  plain and the tightened setup.
- **Public address:** behind the router's NAT the app learns its public address from a
  STUN server (`ice_servers`), or it is configured (`host_to_srflx_ip_mapper`), since
  inside Docker the app only sees its container address (#147).
- **TURN:** the server is reachable on public UDP ports, so most customers connect
  directly, even behind home routers. Networks that block UDP entirely (some offices,
  hotels) would need TURN over TCP/TLS; `ex_webrtc` has no ICE over TCP yet and `rel`
  speaks UDP only. Proposal: no TURN at first; record failed connections in the
  `Call` resource and add coturn (or `rel`, once it can) if they occur (#146).
- **Bandwidth:** each participant's video is sent once to the server and once from the
  server to each other participant. Two participants with video are about 2–4 Mbit/s
  up and down at the server, a screen share more in bursts. Fine for the demo server;
  worth stating in the operating guide.
- **Codecs:** Opus and VP8 only (all current browsers, Safari since 12.1): with one
  codec per kind, packets are forwarded unchanged between the two browsers.

## 7. Operations and observability

- `ex_webrtc_dashboard` as an additional page of the LiveDashboard (`/admin/system`):
  live statistics per peer connection (bitrate, packet loss, round-trip time).
- Telemetry from the room (calls started, ended, failed, duration) in the LiveDashboard
  metrics.
- A call whose connection fails (no media within some seconds) becomes an incident
  (#105) with the ICE details, so blocked UDP shows up.
- Operating guide: ports, firewall and router, bandwidth, how to test a call.

## 8. Testing

- **Room tests with two Elixir peers:** the tests start `ExWebRTC.PeerConnection`
  clients that play the browsers, connect to a room over localhost, send RTP packets
  and assert they arrive at the other participant. A real end-to-end test of the media
  path without a browser.
- **LiveView tests** for the call UI and signaling events (ringing, accept, decline,
  hang up, permissions for customer, consultant, other customers and visitors).
- **Policy tests** for who may start and join a call.
- **By hand:** Chrome, Firefox and Safari, desktop and phone, on the demo server through
  the real router; a call while browsing the shop; screen sharing both ways.

## 9. Implementation order (one commit each, with tests)

1. ✅ Dependency, room process and two-peer test: audio and video forwarded between two
   Elixir peers; configuration (port range, ICE servers). *Done 2026-10-16:*
   `Mercator.Consulting.Calls` (API, `CALL_PORT_RANGE` and `CALL_ICE_SERVERS`) and
   `Calls.Room`; `Mercator.FakeBrowser` (test support) plays a browser with its own
   `PeerConnection`. The Docker builder needs `libssl-dev` and `pkg-config` for
   `ex_dtls`; checked with a local image build and a WebRTC offer inside the release.
2. ✅ `Call` resource, policies, start/accept/decline/hang up in the domain; system
   messages in the chat. *Done 2026-10-16:* `Mercator.Consulting.Call` (ringing →
   active → ended; end reasons completed, declined, missed, cancelled, failed; at most
   one open call per conversation by a partial unique index; `accept` and `finish`
   only apply while the call is still open in the database, so two hang-ups at once
   end it once). The consultant calls and hangs up via `Desk.call/3` and
   `Desk.hang_up/2`, the customer answers, declines, hangs up and asks for a call via
   `Conversations`; `Calls.finish/2` ends the media and writes "Videoanruf,
   14:05–14:20", "Verpasster Anruf" etc. into the chat; `WatchCall` ends unanswered
   calls after `:call_ring_seconds` (45). The room now stops its peer connections
   (they were only closed before) and links them.
3. ✅ Browser side: the "Call" hook (getUserMedia, RTCPeerConnection) and the call UI
   in the chat panel and the desk; audio and camera. *Done 2026-10-16 (code and
   LiveView tests; by hand: pending):* `assets/js/hooks/call.js` (answers the room's
   offer once, fills the fixed channels, mute and camera buttons, warns before leaving
   the page), `MercatorWeb.CallComponents.call_media/1`; the customer answers or
   declines in the chat panel (which opens when a call rings) and can ask for a call;
   the consultant calls (audio or video) from the conversation's header. *(At first
   the call belonged to the selected conversation and switching hung up; since #150
   it lives in a floating card.)* A reload rejoins the call (the room replaces the connection). `WatchCall`
   (formerly `ExpireCall`) also ends active calls whose media room has been empty
   for more than 30 seconds after the answer. Tested by hand 2026-10-16: Firefox ↔ Chrome
   in both directions, on localhost (not inside the Tidewave page, whose frame blocks
   camera and microphone). The chat panel can now be resized at its top-left corner
   (kept per browser), for big screens.
4. ✅ Screen sharing, device selection, speaking indicator, full-screen view. *Done
   2026-10-16 (code and tests; tested by hand):* screen sharing both ways through
   the third channel, the newest share wins (the room relays "screen on/off" between
   the participants, `Calls.screen_share/3` notes it on the call); microphone and
   camera chosen in a small device panel, switched live with `replaceTrack`; a ring
   around the call box while the other speaks, and around the mute button while one
   speaks (Web Audio level); the call box in full screen. The room's `join` waits up to
   20 s (creating the DTLS certificate is slow on a busy machine). Tested by hand
   2026-10-16: screen sharing and full screen work; switching the microphone during a
   call works; switching conversations on the desk keeps the call connected (#150). The speaking
   ring works. Added after the test: a ringtone for the customer while a call rings
   and a ringback tone for the consultant (`assets/js/hooks/ringtone.js`, generated
   with Web Audio, no audio file).
5. Deployment: UDP range in Docker, STUN/public address, operating guide; tested on the
   demo server. ✅ *Done 2026-10-16, tested on biber.mittenin.at with a phone on
   mobile data as the customer (through the router's port forwarding, no TURN):* `docker-compose.yml`
   publishes `CALL_PORT_RANGE` (default 50000–50049) one to one and gives the app a
   fixed address on its own network (`APP_IP` 172.30.0.10 in `MERCATOR_SUBNET`
   172.30.0.0/24); `CALL_PUBLIC_HOST` is resolved for every call and offered to the
   browsers instead of the container address (`host_to_srflx_ip_mapper`), which also
   follows a home IP behind DynDNS; STUN stays optional. Documented in DOCKER.md and
   the operating guide (new chapter "Videoanrufe" / "Video calls", configuration,
   troubleshooting).
6. ✅ Observability: WebRTC dashboard page, telemetry, incidents for failed calls. *Done
   2026-10-16:* `ex_webrtc_dashboard` as the page "WebRTC" under `/admin/system`;
   telemetry `[:mercator, :call, :start]` (video or not) and `[:mercator, :call, :stop]`
   (reason, seconds talked) on the Metrics page; when a connection fails, the room
   sends that participant's LiveView a summary of the ICE candidates and checks, and
   `Calls.connection_failed/3` ends the call as failed and reports an incident with it
   (the browser gets the state without the details). The WebRTC page was tested by hand with a running
   call.
7. Documentation (manual, help, operating) and the Biber Holz demo.

## 10. Questions (answered 2026-10-16)

- ~~**#140 Visitors**~~ *(answered 2026-10-16: yes)* Visitors without an account (who can chat, #94) can take a call too; the call is part of their conversation, and the consultant decides to call.
- ~~**#141 Who starts**~~ *(answered 2026-10-16: as recommended)* The consultant calls; the customer can ask for a call with a button, which rings at the desk. The customer cannot ring the desk directly, so nobody is surprised by an incoming video call.
- ~~**#142 Camera defaults**~~ *(answered 2026-10-16: yes)* The customer joins with audio only and turns the camera on if they want; the consultant's camera is on.
- ~~**#143 Screen sharing**~~ *(answered 2026-10-16: yes)* Both directions (the consultant shows a plan or the configurator, the customer their sketch), one share at a time.
- ~~**#144 Participants**~~ *(answered 2026-10-16: two, it is a prototype)* The
  customer and the consultant who has taken the conversation.
- ~~**#145 Recording**~~ *(answered 2026-10-16: none)* No recording at all (consent, storage, GDPR); possible later with Membrane if ever needed.
- ~~**#146 TURN**~~ *(answered 2026-10-16: none at first)* Failed connections are recorded (`Call`, incidents); coturn, or `rel` once it supports TCP/TLS, only if they occur.
- ~~**#147 Docker networking**~~ *(answered 2026-10-16: a published UDP range)* With
  the same port numbers on host and container, a fixed container IP on the app's own
  Compose network, and the firewall allowing the range for that IP only (section 6).
  `network_mode: host` is not used.
- ~~**#148 History**~~ *(answered 2026-10-16: yes)* A `Call` resource plus a system message in the chat (section 5).
- ~~**#149 Privacy notice**~~ *(answered 2026-10-16: yes)* A short note before the first call ("Ihr Anruf läuft über unseren Server und wird nicht aufgezeichnet.") and a paragraph for the privacy policy page (CMS).
