defmodule TeamCalendar.MonthLayoutTest do
  use ExUnit.Case, async: true

  alias TeamCalendar.MonthLayout

  defp event(id, starts_on, ends_on), do: %{id: id, starts_on: starts_on, ends_on: ends_on}

  defp by_id(segments), do: Map.new(segments, &{&1.event.id, &1})

  describe "weeks/1 and grid_range/1" do
    test "shows six Sunday-first weeks covering the month" do
      weeks = MonthLayout.weeks(~D[2026-11-20])

      assert length(weeks) == 6
      assert hd(weeks) == ~D[2026-11-01]
      assert Enum.all?(weeks, &(Date.day_of_week(&1, :sunday) == 1))
      assert MonthLayout.grid_range(~D[2026-11-20]) == {~D[2026-11-01], ~D[2026-12-12]}
    end

    test "starts in the previous month when the 1st is not a Sunday" do
      assert MonthLayout.grid_range(~D[2026-10-01]) == {~D[2026-09-27], ~D[2026-11-07]}
    end
  end

  describe "week_segments/2" do
    test "stacks overlapping events, longest first" do
      events = [
        event(1, ~D[2026-11-16], ~D[2026-11-17]),
        event(2, ~D[2026-11-16], ~D[2026-11-17]),
        event(3, ~D[2026-11-15], ~D[2026-11-18])
      ]

      {segments, lanes} = MonthLayout.week_segments(events, ~D[2026-11-15])
      segments = by_id(segments)

      assert lanes == 3
      assert %{lane: 0, col: 1, span: 4} = segments[3]
      assert %{lane: 1, col: 2, span: 2} = segments[1]
      assert %{lane: 2, col: 2, span: 2} = segments[2]
    end

    test "reuses a lane once the earlier event has ended" do
      events = [
        event(1, ~D[2026-11-15], ~D[2026-11-16]),
        event(2, ~D[2026-11-17], ~D[2026-11-18]),
        event(3, ~D[2026-11-16], ~D[2026-11-17])
      ]

      {segments, lanes} = MonthLayout.week_segments(events, ~D[2026-11-15])
      segments = by_id(segments)

      assert lanes == 2
      assert segments[1].lane == 0
      assert segments[2].lane == 0
      assert segments[3].lane == 1
    end

    test "clips an event that crosses week boundaries into one segment per week" do
      events = [event(1, ~D[2026-11-19], ~D[2026-11-24])]

      {[first], 1} = MonthLayout.week_segments(events, ~D[2026-11-15])
      assert %{col: 5, span: 3, starts_here?: true, ends_here?: false} = first

      {[second], 1} = MonthLayout.week_segments(events, ~D[2026-11-22])
      assert %{col: 1, span: 3, starts_here?: false, ends_here?: true} = second
    end

    test "puts an event continuing from last week above ones starting this week" do
      events = [
        event(1, ~D[2026-11-22], ~D[2026-11-28]),
        event(2, ~D[2026-11-20], ~D[2026-11-23])
      ]

      {segments, 2} = MonthLayout.week_segments(events, ~D[2026-11-22])
      segments = by_id(segments)

      assert segments[2].lane == 0
      assert segments[1].lane == 1
    end

    test "ignores events outside the week" do
      events = [
        event(1, ~D[2026-11-14], ~D[2026-11-14]),
        event(2, ~D[2026-11-22], ~D[2026-11-22])
      ]

      assert MonthLayout.week_segments(events, ~D[2026-11-15]) == {[], 0}
    end
  end
end
