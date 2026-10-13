defmodule Mercator.Accounts do
  use Ash.Domain,
    otp_app: :mercator

  resources do
    resource Mercator.Accounts.Token
    resource Mercator.Accounts.User
  end
end
