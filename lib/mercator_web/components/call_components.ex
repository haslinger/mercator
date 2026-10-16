defmodule MercatorWeb.CallComponents do
  @moduledoc """
  The call area of the customer's chat panel (`MercatorWeb.ChatLive`) and of
  the sales desk (`MercatorWeb.Admin.DeskLive`), video advice (phase 10):
  the other participant's camera and screen, the own camera, and the mute
  and camera buttons. The media is handled by the `Call` hook
  (assets/js/hooks/call.js), which owns this markup (`phx-update="ignore"`).
  """
  use MercatorWeb, :html

  attr :id, :string, default: "call-media"
  attr :video, :boolean, default: false, doc: "start with the camera on"
  attr :peer, :string, required: true, doc: "the other participant's name"

  def call_media(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="Call"
      phx-update="ignore"
      data-video={to_string(@video)}
      class="space-y-2"
    >
      <%!-- layers in one 16:9 box: name, the other camera, a shared screen, own camera --%>
      <div class="relative aspect-video overflow-hidden rounded-box bg-neutral text-neutral-content">
        <div class="absolute inset-0 flex items-center justify-center gap-2 text-sm opacity-80">
          <.icon name="hero-phone" class="size-5" />
          <span>{@peer}</span>
        </div>
        <video
          data-remote-camera
          autoplay
          playsinline
          class="absolute inset-0 hidden h-full w-full object-cover"
        ></video>
        <video
          data-remote-screen
          autoplay
          playsinline
          class="absolute inset-0 hidden h-full w-full bg-black object-contain"
        ></video>
        <video
          data-local-camera
          autoplay
          playsinline
          muted
          class="absolute right-2 bottom-2 hidden w-1/4 rounded-box border border-base-100/40 object-cover shadow"
        ></video>
        <audio data-remote-audio autoplay></audio>
        <p
          data-call-status
          data-text-preparing={gettext("Starting microphone …")}
          data-text-connecting={gettext("Connecting …")}
          data-text-failed={gettext("The connection failed.")}
          data-text-disconnected={gettext("Connection interrupted …")}
          data-text-peer-left={gettext("%{name} has left the call.", name: @peer)}
          class="absolute top-2 left-2 hidden rounded-box bg-black/60 px-2 py-1 text-xs"
        >
        </p>
      </div>
      <div class="flex justify-center gap-2">
        <button
          type="button"
          data-call-mute
          aria-pressed="false"
          class="btn btn-sm btn-circle"
          title={gettext("Microphone on/off")}
          aria-label={gettext("Microphone on/off")}
        >
          <.icon name="hero-microphone" class="size-4" />
        </button>
        <button
          type="button"
          data-call-camera
          aria-pressed="false"
          class="btn btn-sm btn-circle"
          title={gettext("Camera on/off")}
          aria-label={gettext("Camera on/off")}
        >
          <.icon name="hero-video-camera" class="size-4" />
        </button>
      </div>
    </div>
    """
  end
end
