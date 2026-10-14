defmodule MercatorWeb.Admin.PageComponents do
  @moduledoc "Small components shared by the CMS pages in the back office."
  use Phoenix.Component
  use Gettext, backend: MercatorWeb.Gettext

  attr :state, :atom, required: true
  attr :id, :string, default: nil

  def page_state_badge(assigns) do
    ~H"""
    <span
      class={[
        "badge badge-sm",
        @state == :published && "badge-success",
        @state == :hidden && "badge-warning",
        @state == :draft && "badge-ghost",
        @state == :archived && "badge-neutral"
      ]}
      id={@id}
    >
      {page_state_label(@state)}
    </span>
    """
  end

  @doc "The translated name of a page state."
  def page_state_label(:draft), do: pgettext("page state", "Draft")
  def page_state_label(:published), do: pgettext("page state", "Published")
  def page_state_label(:hidden), do: pgettext("page state", "Hidden")
  def page_state_label(:archived), do: pgettext("page state", "Archived")

  @doc "The translated name of a menu placement."
  def menu_label(:none), do: gettext("Not in a menu")
  def menu_label(:main), do: gettext("Main navigation")
  def menu_label(:footer), do: gettext("Footer")

  @doc "Options for the menu select."
  def menu_options, do: Enum.map([:none, :main, :footer], &{menu_label(&1), &1})

  # All Heroicons (outline, the set Phoenix ships). Listed literally so
  # Tailwind generates their CSS; regenerate when the heroicons dep changes.
  @icons ~w(
    hero-academic-cap hero-adjustments-horizontal hero-adjustments-vertical
    hero-archive-box hero-archive-box-arrow-down hero-archive-box-x-mark hero-arrow-down
    hero-arrow-down-circle hero-arrow-down-left hero-arrow-down-on-square
    hero-arrow-down-on-square-stack hero-arrow-down-right hero-arrow-down-tray
    hero-arrow-left hero-arrow-left-circle hero-arrow-left-end-on-rectangle
    hero-arrow-left-on-rectangle hero-arrow-left-start-on-rectangle hero-arrow-long-down
    hero-arrow-long-left hero-arrow-long-right hero-arrow-long-up hero-arrow-path
    hero-arrow-path-rounded-square hero-arrow-right hero-arrow-right-circle
    hero-arrow-right-end-on-rectangle hero-arrow-right-on-rectangle
    hero-arrow-right-start-on-rectangle hero-arrow-small-down hero-arrow-small-left
    hero-arrow-small-right hero-arrow-small-up hero-arrow-top-right-on-square
    hero-arrow-trending-down hero-arrow-trending-up hero-arrow-turn-down-left
    hero-arrow-turn-down-right hero-arrow-turn-left-down hero-arrow-turn-left-up
    hero-arrow-turn-right-down hero-arrow-turn-right-up hero-arrow-turn-up-left
    hero-arrow-turn-up-right hero-arrow-up hero-arrow-up-circle hero-arrow-up-left
    hero-arrow-up-on-square hero-arrow-up-on-square-stack hero-arrow-up-right
    hero-arrow-up-tray hero-arrow-uturn-down hero-arrow-uturn-left hero-arrow-uturn-right
    hero-arrow-uturn-up hero-arrows-pointing-in hero-arrows-pointing-out
    hero-arrows-right-left hero-arrows-up-down hero-at-symbol hero-backspace hero-backward
    hero-banknotes hero-bars-2 hero-bars-3 hero-bars-3-bottom-left
    hero-bars-3-bottom-right hero-bars-3-center-left hero-bars-4 hero-bars-arrow-down
    hero-bars-arrow-up hero-battery-0 hero-battery-100 hero-battery-50 hero-beaker
    hero-bell hero-bell-alert hero-bell-slash hero-bell-snooze hero-bold hero-bolt
    hero-bolt-slash hero-book-open hero-bookmark hero-bookmark-slash hero-bookmark-square
    hero-briefcase hero-bug-ant hero-building-library hero-building-office
    hero-building-office-2 hero-building-storefront hero-cake hero-calculator
    hero-calendar hero-calendar-date-range hero-calendar-days hero-camera hero-chart-bar
    hero-chart-bar-square hero-chart-pie hero-chat-bubble-bottom-center
    hero-chat-bubble-bottom-center-text hero-chat-bubble-left
    hero-chat-bubble-left-ellipsis hero-chat-bubble-left-right hero-chat-bubble-oval-left
    hero-chat-bubble-oval-left-ellipsis hero-check hero-check-badge hero-check-circle
    hero-chevron-double-down hero-chevron-double-left hero-chevron-double-right
    hero-chevron-double-up hero-chevron-down hero-chevron-left hero-chevron-right
    hero-chevron-up hero-chevron-up-down hero-circle-stack hero-clipboard
    hero-clipboard-document hero-clipboard-document-check hero-clipboard-document-list
    hero-clock hero-cloud hero-cloud-arrow-down hero-cloud-arrow-up hero-code-bracket
    hero-code-bracket-square hero-cog hero-cog-6-tooth hero-cog-8-tooth hero-command-line
    hero-computer-desktop hero-cpu-chip hero-credit-card hero-cube hero-cube-transparent
    hero-currency-bangladeshi hero-currency-dollar hero-currency-euro hero-currency-pound
    hero-currency-rupee hero-currency-yen hero-cursor-arrow-rays hero-cursor-arrow-ripple
    hero-device-phone-mobile hero-device-tablet hero-divide hero-document
    hero-document-arrow-down hero-document-arrow-up hero-document-chart-bar
    hero-document-check hero-document-currency-bangladeshi hero-document-currency-dollar
    hero-document-currency-euro hero-document-currency-pound hero-document-currency-rupee
    hero-document-currency-yen hero-document-duplicate hero-document-magnifying-glass
    hero-document-minus hero-document-plus hero-document-text hero-ellipsis-horizontal
    hero-ellipsis-horizontal-circle hero-ellipsis-vertical hero-envelope
    hero-envelope-open hero-equals hero-exclamation-circle hero-exclamation-triangle
    hero-eye hero-eye-dropper hero-eye-slash hero-face-frown hero-face-smile hero-film
    hero-finger-print hero-fire hero-flag hero-folder hero-folder-arrow-down
    hero-folder-minus hero-folder-open hero-folder-plus hero-forward hero-funnel hero-gif
    hero-gift hero-gift-top hero-globe-alt hero-globe-americas hero-globe-asia-australia
    hero-globe-europe-africa hero-h1 hero-h2 hero-h3 hero-hand-raised hero-hand-thumb-down
    hero-hand-thumb-up hero-hashtag hero-heart hero-home hero-home-modern
    hero-identification hero-inbox hero-inbox-arrow-down hero-inbox-stack
    hero-information-circle hero-italic hero-key hero-language hero-lifebuoy
    hero-light-bulb hero-link hero-link-slash hero-list-bullet hero-lock-closed
    hero-lock-open hero-magnifying-glass hero-magnifying-glass-circle
    hero-magnifying-glass-minus hero-magnifying-glass-plus hero-map hero-map-pin
    hero-megaphone hero-microphone hero-minus hero-minus-circle hero-minus-small hero-moon
    hero-musical-note hero-newspaper hero-no-symbol hero-numbered-list hero-paint-brush
    hero-paper-airplane hero-paper-clip hero-pause hero-pause-circle hero-pencil
    hero-pencil-square hero-percent-badge hero-phone hero-phone-arrow-down-left
    hero-phone-arrow-up-right hero-phone-x-mark hero-photo hero-play hero-play-circle
    hero-play-pause hero-plus hero-plus-circle hero-plus-small hero-power
    hero-presentation-chart-bar hero-presentation-chart-line hero-printer
    hero-puzzle-piece hero-qr-code hero-question-mark-circle hero-queue-list hero-radio
    hero-receipt-percent hero-receipt-refund hero-rectangle-group hero-rectangle-stack
    hero-rocket-launch hero-rss hero-scale hero-scissors hero-server hero-server-stack
    hero-share hero-shield-check hero-shield-exclamation hero-shopping-bag
    hero-shopping-cart hero-signal hero-signal-slash hero-slash hero-sparkles
    hero-speaker-wave hero-speaker-x-mark hero-square-2-stack hero-square-3-stack-3d
    hero-squares-2x2 hero-squares-plus hero-star hero-stop hero-stop-circle
    hero-strikethrough hero-sun hero-swatch hero-table-cells hero-tag hero-ticket
    hero-trash hero-trophy hero-truck hero-tv hero-underline hero-user hero-user-circle
    hero-user-group hero-user-minus hero-user-plus hero-users hero-variable
    hero-video-camera hero-video-camera-slash hero-view-columns hero-viewfinder-circle
    hero-wallet hero-wifi hero-window hero-wrench hero-wrench-screwdriver hero-x-circle
    hero-x-mark
  )

  @doc "The icons pages can have in the navigation (Heroicons)."
  def page_icons, do: @icons

  @doc "Icons whose name contains the query; the chosen one stays first."
  def matching_icons(query, chosen) do
    query = query |> to_string() |> String.trim() |> String.downcase()

    found =
      if query == "",
        do: @icons,
        else: Enum.filter(@icons, &String.contains?(&1, query))

    if chosen in @icons and chosen not in found, do: [chosen | found], else: found
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :query, :string, default: ""

  @doc """
  Choose a page's icon: a searchable grid of icons as radio buttons, or
  none. The search field is `icon_q` in the same form.
  """
  def icon_picker(assigns) do
    assigns = assign(assigns, :icons, matching_icons(assigns.query, assigns.field.value))

    ~H"""
    <fieldset class="fieldset" id="icon-picker">
      <legend class="fieldset-legend">{gettext("Icon in the navigation")}</legend>
      <input
        type="search"
        name="icon_q"
        value={@query}
        placeholder={gettext("Search icons (English, e.g. truck, fire)")}
        phx-debounce="200"
        class="input input-sm w-full"
        id="icon-search"
      />
      <div class="grid max-h-56 grid-cols-7 gap-1 overflow-y-auto">
        <label
          class={[
            "btn btn-square btn-sm",
            if(@field.value in [nil, ""], do: "btn-primary", else: "btn-ghost")
          ]}
          title={gettext("No icon")}
        >
          <input
            type="radio"
            name={@field.name}
            value=""
            checked={@field.value in [nil, ""]}
            class="sr-only"
          />
          <MercatorWeb.CoreComponents.icon name="hero-minus" class="size-4" />
        </label>
        <label
          :for={icon <- @icons}
          class={[
            "btn btn-square btn-sm",
            if(@field.value == icon, do: "btn-primary", else: "btn-ghost")
          ]}
          title={String.replace_prefix(icon, "hero-", "")}
          id={"icon-#{icon}"}
        >
          <input
            type="radio"
            name={@field.name}
            value={icon}
            checked={@field.value == icon}
            class="sr-only"
          />
          <MercatorWeb.CoreComponents.icon name={icon} class="size-5" />
        </label>
      </div>
      <p :if={@icons == []} class="text-sm text-base-content/60">{gettext("No icons found.")}</p>
    </fieldset>
    """
  end
end
