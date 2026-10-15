defmodule Mercator.Demo do
  @moduledoc """
  Demo mode (#44–#48, docs/deployment-design.md): one image serves the demo
  and the customers' shops, `MERCATOR_MODE=demo` switches it on.

  In demo mode

    * the demo data is seeded when the app starts with an empty database
      (`seed_if_empty/0`), the administrator with `DEMO_ADMIN_PASSWORD` (#45),
      all other demo users with the public password (#47),
    * the sign-in page lists the public demo logins (`public_logins/0`), and
      these accounts cannot change their password or roles or request a
      password reset (#46, `public_account?/1`),
    * the payment simulator is registered (runtime.exs) and active,
    * everything is reset every night (`reset/0`,
      `Mercator.Demo.Workers.Reset`).
  """
  require Logger

  alias Mercator.Accounts.User
  alias Mercator.{Payments, Repo, Seeds, Uploads}
  alias Mercator.Payments.Simulator
  alias Mercator.Seeds.Images

  @doc "Whether this deployment is the demo."
  def enabled?, do: Application.get_env(:mercator, :demo_mode, false)

  @doc """
  The public demo logins (everybody but the administrators), as maps with
  `:email`, `:name`, `:roles` and `:locale`. Their password is `password/0`.
  """
  def public_logins do
    Seeds.demo_users()
    |> Enum.reject(&(:administrator in &1.roles))
    |> Enum.map(&Map.merge(%{locale: :de}, Map.take(&1, [:email, :name, :roles, :locale])))
  end

  @doc "The password of the public demo logins."
  def password, do: Seeds.demo_password()

  @doc """
  Whether a user (or email) is one of the public demo accounts, which are
  protected against changes in demo mode (#46). Always false outside the demo.
  """
  def public_account?(%{email: email}), do: public_account?(email)

  def public_account?(email) when is_binary(email) or is_struct(email) do
    email = email |> to_string() |> String.downcase()
    enabled?() and Enum.any?(public_logins(), &(&1.email == email))
  end

  def public_account?(_other), do: false

  @doc """
  Seeds the demo data: users, catalogue, pages, orders, conversations and
  offers, the photos from `:demo_image_dir` if there are any, and activates
  the payment simulator. Idempotent. Returns the demo users.
  """
  def seed do
    users = Seeds.run(admin_password: Application.get_env(:mercator, :demo_admin_password))

    with dir when is_binary(dir) <- Application.get_env(:mercator, :demo_image_dir),
         true <- File.dir?(dir) do
      Images.import(dir)
    end

    activate_simulator(users)
    users
  end

  @doc "Seeds the demo data unless there are users already (at start, in demo mode)."
  def seed_if_empty do
    if Ash.exists?(User, authorize?: false) do
      :ok
    else
      Logger.info("Demo mode: empty database, seeding the demo data")
      seed()
      Logger.info("Demo mode: demo data seeded")
      :ok
    end
  end

  @doc """
  Resets the demo: empties all tables (except the migrations and the
  background jobs), deletes the uploads and seeds again. Accounts that
  visitors registered are gone too. Other pending jobs are dropped, except
  `keep_job_id` (the job running the reset).
  """
  def reset(keep_job_id \\ nil) do
    Repo.query!("TRUNCATE #{Enum.join(tables(), ", ")} RESTART IDENTITY CASCADE")
    drop_jobs(keep_job_id)
    clear_uploads()
    Simulator.clear()
    seed()
    :ok
  end

  defp tables do
    %{rows: rows} =
      Repo.query!("""
      SELECT quote_ident(tablename) FROM pg_tables
      WHERE schemaname = 'public'
        AND tablename <> 'schema_migrations'
        AND tablename NOT LIKE 'oban\\_%'
      ORDER BY tablename
      """)

    List.flatten(rows)
  end

  defp drop_jobs(nil), do: Repo.query!("DELETE FROM oban_jobs")
  defp drop_jobs(id), do: Repo.query!("DELETE FROM oban_jobs WHERE id <> $1", [id])

  defp clear_uploads do
    root = Uploads.root()

    with {:ok, entries} <- File.ls(root) do
      Enum.each(entries, &File.rm_rf!(Path.join(root, &1)))
    end
  end

  defp activate_simulator(users) do
    admin = Enum.find(users, &(:administrator in &1.roles))

    if Payments.provider(Simulator.key()) do
      {:ok, _setting} = Payments.activate(Simulator.key(), admin)
    end
  end
end
