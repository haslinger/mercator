defmodule Mercator.Content.Submission do
  @moduledoc """
  A message from the contact form (#83): stored, emailed to the shop
  (`Mercator.Content.Workers.SendSubmission`) and listed in the back office,
  where staff mark it as handled.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Content.Workers.SendSubmission

  postgres do
    table "submissions"
    repo Mercator.Repo

    references do
      reference :page, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :submit do
      description "A visitor sends the contact form."
      accept [:name, :email, :phone, :message, :page_id, :locale]

      validate match(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/),
        message: dgettext_noop("errors", "is not a valid email address")

      change after_action(fn _changeset, submission, _context ->
               %{submission_id: submission.id}
               |> SendSubmission.new()
               |> Oban.insert!()

               {:ok, submission}
             end)
    end

    update :mark_handled do
      change set_attribute(:handled, true)
    end

    update :mark_open do
      change set_attribute(:handled, false)
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy action(:submit) do
      authorize_if always()
    end

    policy action_type([:read, :update]) do
      authorize_if {ActorHasRole, role: :sales}
      authorize_if {ActorHasRole, role: :sales_manager}
      authorize_if {ActorHasRole, role: :contentmanager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :email, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :phone, :string, public?: true, constraints: [max_length: 50]

    attribute :message, :string do
      allow_nil? false
      public? true
      constraints max_length: 5000
    end

    attribute :locale, :string, public?: true, default: "de"
    attribute :handled, :boolean, allow_nil?: false, default: false, public?: true

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :page, Mercator.Content.Page, public?: true
  end
end
