File.rm_rf!(Application.fetch_env!(:mercator, :uploads_dir))
# call tests (phase 10): connections that close after a test has ended make
# the ICE library warn outside the test's log capture
Logger.put_application_level(:ex_ice, :error)
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Mercator.Repo, :manual)
