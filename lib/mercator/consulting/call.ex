defmodule Mercator.Consulting.Call do
  @moduledoc """
  An audio or video call in a conversation (phase 10, docs/video-design.md,
  section 5, #148): who called, when it was answered and ended, and how.

  The consultant calls (#141); the customer accepts or declines. States:
  `ringing` → `active` → `ended`, or `ringing` → `ended` when the call is
  declined, missed or cancelled. At most one call per conversation is
  ringing or active. The media itself runs in `Mercator.Consulting.Calls.Room`.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Consulting,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "conversation_calls"
    repo Mercator.Repo

    references do
      reference :conversation, on_delete: :delete
      reference :consultant, on_delete: :nilify
    end

    identity_wheres_to_sql one_open_call: "state IN ('ringing', 'active')"
  end

  state_machine do
    initial_states [:ringing]
    default_initial_state :ringing

    transitions do
      transition :accept, from: [:ringing], to: :active
      transition :finish, from: [:ringing, :active], to: :ended
    end
  end

  actions do
    defaults [:read]

    create :start do
      description "The consultant (the actor) calls the customer of a conversation."
      accept [:conversation_id, :video]
      change relate_actor(:consultant)
    end

    update :accept do
      description "The customer answers."
      accept []
      # only while still ringing in the database (a hang-up may have come first)
      change filter(expr(state == :ringing))
      change transition_state(:active)
      change set_attribute(:answered_at, &DateTime.utc_now/0)
    end

    update :finish do
      accept [:end_reason]
      validate present(:end_reason)
      # only once: two hang-ups at the same moment, or a hang-up and the
      # ring timeout, must not both end the call
      change filter(expr(state in [:ringing, :active]))
      change transition_state(:ended)
      change set_attribute(:ended_at, &DateTime.utc_now/0)
    end

    update :note_media do
      description "Video or screen sharing was used during the call (for the history)."
      accept [:video, :screen_shared]
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy always() do
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :video, :boolean do
      description "Whether a camera was used; the call may start with audio only."
      allow_nil? false
      default false
      public? true
    end

    attribute :screen_shared, :boolean, allow_nil?: false, default: false, public?: true

    attribute :answered_at, :utc_datetime_usec, public?: true
    attribute :ended_at, :utc_datetime_usec, public?: true

    attribute :end_reason, :atom do
      description """
      completed (answered and hung up), declined (by the customer), missed
      (not answered in time), cancelled (the consultant hung up before an
      answer), failed (the connection could not be made or broke).
      """

      public? true
      constraints one_of: [:completed, :declined, :missed, :cancelled, :failed]
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :conversation, Mercator.Consulting.Conversation, allow_nil?: false, public?: true
    belongs_to :consultant, Mercator.Accounts.User, public?: true
  end

  identities do
    identity :one_open_call, [:conversation_id],
      where: expr(state in [:ringing, :active]),
      message: "already has a call"
  end
end
