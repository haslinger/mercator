defmodule MercatorWeb.AuthOverrides do
  @moduledoc """
  DaisyUI styling for the AshAuthentication.Phoenix pages (sign in, register,
  password reset, magic link, confirmation). Sign out has its own page,
  `MercatorWeb.SignOutLive`.

  Texts are translated through the `"auth"` Gettext domain
  (`priv/gettext/*/LC_MESSAGES/auth.po`), see the router.

  Reference: https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html
  """
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.{
    Components,
    ConfirmLive,
    MagicSignInLive,
    ResetLive,
    SignInLive
  }

  @page "min-h-screen grid place-items-center bg-base-200 px-4 py-12"
  @card "card w-full max-w-md bg-base-100 shadow-xl p-8"
  @heading "text-2xl font-bold mb-4"
  @primary_button "btn btn-primary w-full mt-4"

  # --- Pages -----------------------------------------------------------------

  for live <- [SignInLive, ResetLive, ConfirmLive, MagicSignInLive] do
    override live do
      set :root_class, @page
    end
  end

  override Components.SignIn do
    set :root_class, @card
    set :strategy_class, "w-full"
    set :authentication_error_container_class, "alert alert-error mt-4"
    set :authentication_error_text_class, ""
  end

  override Components.Reset do
    set :root_class, @card
    set :strategy_class, "w-full"
  end

  override Components.Confirm do
    set :root_class, @card
    set :strategy_class, "w-full"
  end

  override Components.Confirm.Input do
    set :submit_class, @primary_button
  end

  # --- Shared building blocks -------------------------------------------------

  # /brand/logo always points to the logo of the configured brand
  override Components.Banner do
    set :root_class, "w-full flex justify-center pb-4"
    set :href_url, "/"
    set :href_class, nil
    set :image_url, "/brand/logo"
    set :image_class, "h-28 w-auto"
    set :dark_image_url, "/brand/logo"
    set :dark_image_class, "hidden"
    set :text, nil
    set :text_class, nil
  end

  override Components.HorizontalRule do
    set :root_class, "divider"
    set :hr_outer_class, "hidden"
    set :hr_inner_class, nil
    set :text_outer_class, nil
    set :text_inner_class, nil
    # the library does not translate this text, so show a plain line
    set :text, nil
  end

  override Components.Flash do
    set :message_class_info, "alert alert-info fixed top-4 right-4 w-80 sm:w-96 z-50"
    set :message_class_error, "alert alert-error fixed top-4 right-4 w-80 sm:w-96 z-50"
  end

  # --- Password strategy -----------------------------------------------------

  override Components.Password do
    set :root_class, nil
    set :interstitial_class, "flex flex-wrap justify-between gap-2 mt-4 text-sm"
    set :toggler_class, "link link-primary"
  end

  for form <- [
        Components.Password.SignInForm,
        Components.Password.RegisterForm,
        Components.Password.ResetForm,
        Components.Reset.Form
      ] do
    override form do
      set :label_class, @heading
    end
  end

  override Components.Password.Input do
    set :field_class, "fieldset"
    set :label_class, "fieldset-legend"
    set :input_class, "input w-full"
    set :input_class_with_error, "input input-error w-full"
    set :submit_class, @primary_button
    set :error_ul, "text-error text-sm mt-1"
    set :remember_me_class, "flex items-center gap-2 mt-2"
    set :checkbox_class, "checkbox checkbox-sm"
    set :checkbox_label_class, "label text-sm"
  end

  # --- Magic link strategy ---------------------------------------------------

  override Components.MagicLink do
    set :root_class, nil
    set :label_class, @heading
  end

  override Components.MagicLink.Input do
    set :submit_class, "btn btn-outline btn-primary w-full mt-4"
    set :remember_me_class, "flex items-center gap-2 mt-2"
    set :checkbox_class, "checkbox checkbox-sm"
    set :checkbox_label_class, "label text-sm"
  end
end
