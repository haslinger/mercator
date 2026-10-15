defmodule MercatorWeb.SignInLive do
  @moduledoc """
  The sign-in, register and password-reset page: AshAuthentication's
  `SignIn` component (styled by `MercatorWeb.AuthOverrides`) plus, in demo
  mode, the public demo logins (`MercatorWeb.DemoComponents.demo_logins/1`).
  Mounting and session handling are AshAuthentication's own.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.DemoComponents, only: [demo_logins: 1]

  alias AshAuthentication.Phoenix.Components.SignIn
  alias AshAuthentication.Phoenix.SignInLive, as: Base

  @impl true
  defdelegate mount(params, session, socket), to: Base

  @impl true
  defdelegate handle_params(params, uri, socket), to: Base

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- centered as a block; the demo card goes right of the form on wide screens --%>
    <div class={[
      MercatorWeb.AuthOverrides.page_class(),
      "content-center justify-center gap-6 grid-cols-[minmax(0,28rem)]",
      Mercator.Demo.enabled?() && "lg:grid-cols-[28rem_28rem] lg:items-start"
    ]}>
      <.live_component
        module={SignIn}
        otp_app={@otp_app}
        live_action={@live_action}
        path={@path}
        auth_routes_prefix={@auth_routes_prefix}
        resources={@resources}
        reset_path={@reset_path}
        register_path={@register_path}
        id="sign-in"
        overrides={@overrides}
        current_tenant={@current_tenant}
        context={@context}
        gettext_fn={@gettext_fn}
      />
      <.demo_logins logins?={@live_action == :sign_in} />
    </div>
    """
  end
end
