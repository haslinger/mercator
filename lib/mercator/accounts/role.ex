defmodule Mercator.Accounts.Role do
  @moduledoc """
  Staff roles a user can hold (any combination). Customers have no role.

    * `:administrator` – full access, manages users and roles
    * `:sales` – consultant: conversations and offers
    * `:sales_manager` – approves offers
    * `:contentmanager` – CMS pages and content elements
    * `:productmanager` – catalogue: categories, products, prices
  """
  use Ash.Type.Enum,
    values: [:administrator, :sales, :sales_manager, :contentmanager, :productmanager]
end
