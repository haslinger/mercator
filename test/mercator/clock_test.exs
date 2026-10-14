defmodule Mercator.ClockTest do
  use ExUnit.Case, async: true

  alias Mercator.Clock

  test "shows UTC times in the shop's time zone (#73)" do
    assert Clock.time_zone() == "Europe/Vienna"
    assert Clock.local(~U[2026-10-13 22:30:00Z]) |> DateTime.to_date() == ~D[2026-10-14]
    assert Clock.local(~U[2026-01-13 22:30:00Z]) |> DateTime.to_date() == ~D[2026-01-13]
  end

  test "a local day starts at local midnight, in summer and winter time" do
    assert Clock.start_of_day(~D[2026-07-01]) == ~U[2026-06-30 22:00:00Z]
    assert Clock.start_of_day(~D[2026-12-01]) == ~U[2026-11-30 23:00:00Z]
    # the day of the switch to summer time
    assert Clock.start_of_day(~D[2026-03-29]) == ~U[2026-03-28 23:00:00Z]
  end

  test "today is a date" do
    assert %Date{} = Clock.today()
  end
end
