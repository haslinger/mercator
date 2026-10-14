defmodule MercatorWeb.SignOutLive do
  @moduledoc """
  Confirmation page for `GET /sign-out`, in place of AshAuthentication's
  untranslated one. Signing out itself needs a `DELETE /sign-out` (protection
  against logout CSRF); the user menu sends that directly, so this page is
  only seen when the URL is opened.
  """
  use MercatorWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen grid place-items-center bg-base-200 px-4 py-12">
      <div class="card w-full max-w-md bg-base-100 shadow-xl p-8" id="sign-out">
        <.link navigate={~p"/"} class="mb-6 self-center">
          <img src={~p"/brand/logo"} alt={Mercator.Brand.name()} class="h-16 w-auto" />
        </.link>
        <h2 class="text-2xl font-bold mb-4">{gettext("Sign out")}</h2>
        <p class="mb-4">{gettext("Do you want to sign out?")}</p>
        <.form for={%{}} action={~p"/sign-out"} method="delete" id="sign-out-form">
          <button type="submit" class="btn btn-primary w-full">{gettext("Sign out")}</button>
        </.form>
        <.link navigate={~p"/"} class="btn btn-ghost w-full mt-2" id="sign-out-cancel">
          {gettext("Cancel")}
        </.link>
      </div>
    </div>
    """
  end
end
