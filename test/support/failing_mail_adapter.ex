defmodule Mercator.FailingMailAdapter do
  @moduledoc "A Swoosh adapter whose deliveries always fail (SMTP down)."
  use Swoosh.Adapter

  @impl true
  def deliver(_email, _config), do: {:error, {:send, {:permanent_failure, "553 rejected"}}}
end
