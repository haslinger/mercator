defmodule Mercator.Clock do
  @moduledoc """
  The shop's local time (#73). Times are stored in UTC; they are shown in the
  shop's time zone (config `:time_zone`, default `Europe/Vienna`), and "today"
  is the local date, e.g. for price validity and the year of order numbers.
  """

  @doc "The configured time zone of the shop."
  def time_zone, do: Application.get_env(:mercator, :time_zone, "Europe/Vienna")

  @doc "Today's date in the shop's time zone."
  def today, do: DateTime.to_date(local(DateTime.utc_now()))

  @doc "A UTC datetime in the shop's time zone."
  def local(%DateTime{} = datetime), do: DateTime.shift_zone!(datetime, time_zone())

  @doc "The (UTC) moment the given local date begins in the shop's time zone."
  def start_of_day(%Date{} = date) do
    case DateTime.new(date, ~T[00:00:00], time_zone()) do
      {:ok, datetime} -> DateTime.shift_zone!(datetime, "Etc/UTC")
      # midnight skipped by a DST change: the day starts at the end of the gap
      {:gap, _before, just_after} -> DateTime.shift_zone!(just_after, "Etc/UTC")
      {:ambiguous, first, _second} -> DateTime.shift_zone!(first, "Etc/UTC")
    end
  end
end
