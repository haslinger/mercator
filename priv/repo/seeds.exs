# Seeds demo data for development:
#
#     mix run priv/repo/seeds.exs
#
# Safe to run repeatedly. Demo users are not created in production.

if Mix.env() == :prod do
  IO.puts("Skipping demo data in production.")
else
  users = Mercator.Seeds.run()

  IO.puts("Demo users (password: #{Mercator.Seeds.demo_password()}):")

  for user <- users do
    roles = Enum.map_join(user.roles, ", ", &to_string/1)

    IO.puts(
      "  #{String.pad_trailing(to_string(user.email), 22)} #{String.pad_trailing(user.name, 16)} #{roles}"
    )
  end
end
