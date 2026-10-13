File.rm_rf!(Application.fetch_env!(:mercator, :uploads_dir))
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Mercator.Repo, :manual)
