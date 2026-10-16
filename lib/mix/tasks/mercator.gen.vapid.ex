defmodule Mix.Tasks.Mercator.Gen.Vapid do
  @shortdoc "Generates a key pair for phone notifications (Web Push)"
  @moduledoc """
  Generates the shop's key pair for Web Push (#151, `Mercator.WebPush`) and
  prints it as environment variables for the deployment:

      mix mercator.gen.vapid

  One key pair per shop. A new key pair makes every device switch
  notifications on again at the desk.
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    {public, private} = Mercator.WebPush.generate_keys()

    Mix.shell().info("""
    VAPID_PUBLIC_KEY=#{public}
    VAPID_PRIVATE_KEY=#{private}
    """)
  end
end
