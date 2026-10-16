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
      data-text-microphone={gettext("Microphone")}
      data-text-camera={gettext("Camera")}
      class="space-y-2"
    >
      <%!-- layers in one 16:9 box (full screen on request): name, the other's
           camera, a shared screen, own camera; a ring while the other speaks --%>
      <div
        data-call-box
        class="relative aspect-video overflow-hidden rounded-box bg-neutral text-neutral-content transition-shadow [&:fullscreen]:aspect-auto [&:fullscreen]:rounded-none"
      >
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
        <.call_button name="mute" icon="hero-microphone" label={gettext("Microphone on/off")} />
        <.call_button name="camera" icon="hero-video-camera" label={gettext("Camera on/off")} />
        <.call_button
          name="screen"
          icon="hero-computer-desktop"
          label={gettext("Share screen on/off")}
        />
        <.call_button
          name="fullscreen"
          icon="hero-arrows-pointing-out"
          label={gettext("Full screen")}
        />
        <.call_button
          name="settings"
          icon="hero-adjustments-horizontal"
          label={gettext("Microphone and camera")}
        />
      </div>
      <div data-call-devices class="hidden space-y-2 rounded-box bg-base-200 p-2 text-sm">
        <label class="block">
          <span class="text-xs opacity-70">{gettext("Microphone")}</span>
          <select data-call-mic class="select select-sm w-full"></select>
        </label>
        <label class="block">
          <span class="text-xs opacity-70">{gettext("Camera")}</span>
          <select data-call-cam class="select select-sm w-full"></select>
        </label>
      </div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  # a round control, found by the hook through data-call-<name>
  defp call_button(assigns) do
    ~H"""
    <button
      type="button"
      {%{"data-call-#{@name}" => true}}
      aria-pressed="false"
      class="btn btn-sm btn-circle"
      title={@label}
      aria-label={@label}
    >
      <.icon name={@icon} class="size-4" />
    </button>
    """
  end
end
