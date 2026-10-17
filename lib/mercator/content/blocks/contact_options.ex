defmodule Mercator.Content.Blocks.ContactOptions do
  @moduledoc """
  Block: the ways to get advice side by side (#154): writing in the chat,
  talking (a call in the browser, #155), a message by email (the page with
  the contact form) and the shop's phone number (#159). Shows whether a
  consultant is at the desk right now (#156).
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true, writable?: true
    attribute :headline, Mercator.Translated, public?: true
    attribute :text, Mercator.Translated, public?: true

    attribute :message_link, :string do
      description "The page with the contact form, e.g. /pages/kontakt; without it, no email card."
      public? true
      constraints max_length: 500
    end

    attribute :show_phone, :boolean do
      description "Whether the shop's phone number (brand setting) is shown as a fourth way."
      public? true
      default true
      allow_nil? false
    end
  end
end
