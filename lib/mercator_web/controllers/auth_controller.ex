defmodule MercatorWeb.AuthController do
  use MercatorWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias Mercator.Consulting.Conversations
  alias Mercator.Sales.Baskets
  alias MercatorWeb.BasketSession

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> gettext("Your email address has been confirmed.")
        {:password, :reset} -> gettext("Your password has been reset.")
        _ -> gettext("You are now signed in.")
      end

    # move the visitor basket into the user's basket (#8)
    Baskets.merge(get_session(conn, BasketSession.key()), user)
    Conversations.merge(get_session(conn, BasketSession.key()), user)

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          gettext(
            "You have already signed in another way, but have not confirmed your account. " <>
              "You can confirm your account using the link we sent to you, or by resetting your password."
          )

        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %AshAuthentication.Errors.ConfirmationRequired{}
         }} ->
          gettext(
            "An account with this email already exists. We've sent a link to that address - " <>
              "confirm it to finish linking this provider to your account."
          )

        _ ->
          gettext("Incorrect email or password.")
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"
    chosen_locale = get_session(conn, "chosen_locale")

    conn
    |> clear_session(:mercator)
    |> then(&if(chosen_locale, do: put_session(&1, "chosen_locale", chosen_locale), else: &1))
    |> put_flash(:info, gettext("You are now signed out."))
    |> redirect(to: return_to)
  end
end
