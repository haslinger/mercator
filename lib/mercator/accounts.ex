defmodule Mercator.Accounts do
  @moduledoc """
  Accounts domain: users and authentication tokens.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshPhoenix]

  resources do
    resource Mercator.Accounts.Token

    resource Mercator.Accounts.User do
      define :get_user, action: :read, get_by: [:id]
      define :list_users, action: :read
      define :update_profile, action: :update_profile
      define :change_password, action: :change_password
      define :set_user_roles, action: :set_roles, args: [:roles]
    end
  end
end
