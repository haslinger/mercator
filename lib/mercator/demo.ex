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
  import Ecto.Query, only: [from: 2]

  require Ash.Query

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

  @doc """
  The user of a public demo login by its key (the local part of the email,
  e.g. `"sales"`), for the one-click demo sign-in; nil outside demo mode,
  for unknown keys and for administrators.
  """
  def login_user(key) when is_binary(key) do
    with true <- enabled?(),
         %{email: email} <- Enum.find(public_logins(), &(login_key(&1) == key)) do
      User
      |> Ash.Query.filter(email == ^email)
      |> Ash.read_one!(authorize?: false)
    else
      _ -> nil
    end
  end

  def login_user(_key), do: nil

  @doc "The key of a demo login (the local part of its email), used in forms and DOM ids."
  def login_key(%{email: email}), do: email |> String.split("@") |> hd()

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

  Runs in one transaction: all or nothing, and the background jobs seeding
  creates (emails about the demo conversations and offers) are deleted before
  Oban can see them, so seeding sends no emails.
  """
  def seed do
    {:ok, users} = transact(&seed_data/0)
    users
  end

  # One transaction for all of seeding. Ash collects the notifications of
  # the actions inside; seeding has nobody to notify, so they are dropped.
  defp transact(fun) do
    {:ok, result, _notifications} =
      Ash.transact(User, fun, timeout: :infinity, return_notifications?: true)

    {:ok, result}
  end

  defp seed_data do
    last_job = Repo.one(from j in Oban.Job, select: max(j.id)) || 0
    users = Seeds.run(admin_password: Application.get_env(:mercator, :demo_admin_password))

    with dir when is_binary(dir) <- Application.get_env(:mercator, :demo_image_dir),
         true <- File.dir?(dir) do
      Images.import(dir)
    end

    activate_simulator(users)
    Repo.delete_all(from j in Oban.Job, where: j.id > ^last_job)
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
  Resets the demo: deletes the uploads, empties all tables (except the
  migrations and the background jobs) and seeds again, in one transaction
  (visitors see the old data until it is done). Accounts that visitors
  registered are gone too. Other pending jobs are dropped, except
  `keep_job_id` (the job running the reset).
  """
  # sobelow_skip ["SQL.Query"]
  def reset(keep_job_id \\ nil) do
    clear_uploads()
    Simulator.clear()

    {:ok, _users} =
      transact(fn ->
        Repo.query!("TRUNCATE #{Enum.join(tables(), ", ")} RESTART IDENTITY CASCADE")
        drop_jobs(keep_job_id)
        seed_data()
      end)

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
