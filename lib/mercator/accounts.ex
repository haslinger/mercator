defmodule Mercator.Accounts do
  @moduledoc """
  Accounts domain: users and authentication tokens.
  """
  use Ash.Domain,
    otp_app: :mercator

  resources do
    resource Mercator.Accounts.Token
    resource Mercator.Accounts.User
  end
end
