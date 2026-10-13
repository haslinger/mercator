defmodule Mercator.Accounts do
  @moduledoc """
  Accounts domain: users and authentication tokens.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Mercator.Accounts.Address do
      define :list_my_addresses, action: :mine
      define :get_address, action: :read, get_by: [:id]
      define :create_address, action: :create
      define :update_address, action: :update
      define :destroy_address, action: :destroy
    end

    resource Mercator.Accounts.Token

    resource Mercator.Accounts.User do
      define :get_user, action: :read, get_by: [:id]
      define :list_users, action: :read
      define :update_profile, action: :update_profile
      define :change_password, action: :change_password
      define :set_user_roles, action: :set_roles, args: [:roles]
      define :set_invoice_allowed, action: :set_invoice_allowed, args: [:invoice_allowed]
    end
  end
end
