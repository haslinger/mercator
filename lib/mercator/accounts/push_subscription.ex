defmodule Mercator.Accounts.PushSubscription do
  @moduledoc """
  A device (browser) of a staff member that receives phone notifications
  (Web Push, #151–#153, `Mercator.WebPush`). The browser hands out the
  endpoint and the keys; the endpoint is unique, so a device that someone
  else signs in on moves to them. Deleted when the staff member switches
  notifications off, and when the push service reports the subscription
  gone (the device unsubscribed, e.g. at sign-out).
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "push_subscriptions"
    repo Mercator.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :subscribe do
      description "Stores this device for the actor, or moves it to them."
      accept [:endpoint, :p256dh, :auth, :user_agent]
      upsert? true
      upsert_identity :unique_endpoint
      upsert_fields [:user_id, :p256dh, :auth, :user_agent, :updated_at]
      change set_attribute(:user_id, actor(:id))
    end

    read :mine do
      filter expr(user_id == ^actor(:id))
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    # notifications are for the sales desk
    policy action(:subscribe) do
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end

    policy action_type([:read, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :endpoint, :string do
      description "The push service's address for this device."
      allow_nil? false
      public? true
      constraints max_length: 2000, match: ~r/\Ahttps:\/\//
    end

    attribute :p256dh, :string do
      description "The device's public key (base64url)."
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :auth, :string do
      description "The device's authentication secret (base64url)."
      allow_nil? false
      public? true
      sensitive? true
      constraints max_length: 100
    end

    attribute :user_agent, :string do
      description "Which browser, to tell devices apart."
      public? true
      constraints max_length: 500
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Mercator.Accounts.User, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_endpoint, [:endpoint]
  end
end
