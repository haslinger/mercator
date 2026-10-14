defmodule Mercator.Consulting.Changes.SubmitOffer do
  @moduledoc """
  Submits a draft offer: it is sent to the customer, or waits for a sales
  manager's approval when its highest discount exceeds the limit (#98,
  `config :mercator, :offer_approval_limit`). Offers submitted by a sales
  manager or an administrator need no approval.
  """
  use Ash.Resource.Change
  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Consulting.Offers

  @impl true
  def change(changeset, _opts, context) do
    offer = Ash.load!(changeset.data, :items, authorize?: false)

    cond do
      offer.items == [] ->
        Ash.Changeset.add_error(changeset, field: :items, message: gettext("The offer is empty."))

      Date.before?(offer.valid_until, Mercator.Clock.today()) ->
        Ash.Changeset.add_error(changeset,
          field: :valid_until,
          message: gettext("The validity date is in the past.")
        )

      needs_approval?(offer, context.actor) ->
        AshStateMachine.transition_state(changeset, :pending_approval)

      true ->
        changeset
        |> Ash.Changeset.force_change_attribute(:sent_at, DateTime.utc_now())
        |> AshStateMachine.transition_state(:sent)
    end
  end

  defp needs_approval?(offer, actor), do: not approver?(actor) and Offers.needs_approval?(offer)

  defp approver?(%{roles: roles}) when is_list(roles),
    do: :sales_manager in roles or :administrator in roles

  defp approver?(_actor), do: false
end
