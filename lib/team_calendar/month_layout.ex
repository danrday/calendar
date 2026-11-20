defmodule TeamCalendar.MonthLayout do
  @moduledoc """
  Pure layout maths for the month view.

  A month is drawn as six week rows, Sunday to Saturday. Within a week, each
  event becomes one *segment*: a bar starting at a column, spanning some number
  of days, in a *lane* (vertical slot). Lanes are assigned greedily so that
  overlapping events stack without colliding.
  """

  @weeks 6

  @doc """
  Returns the Sunday that starts each of the six week rows shown for `month`.
  """
  def weeks(%Date{} = month) do
    first = month |> Date.beginning_of_month() |> Date.beginning_of_week(:sunday)
    for week <- 0..(@weeks - 1), do: Date.add(first, week * 7)
  end

  @doc """
  Returns the first and last dates visible in the grid for `month`.
  """
  def grid_range(%Date{} = month) do
    [first | _] = weeks(month)
    {first, Date.add(first, @weeks * 7 - 1)}
  end

  @doc """
  Lays out the events that touch the week starting on `week_start`.

  Returns `{segments, lane_count}`. Each segment is a map with:

    * `:event` - the event
    * `:col` - first column, 1 (Sunday) to 7 (Saturday)
    * `:span` - number of columns covered
    * `:lane` - zero-based vertical slot
    * `:starts_here?` / `:ends_here?` - false when the event continues from the
      previous week or into the next one

  Earlier events get the upper lanes; on a tie the longer event goes first, so
  an event continuing from the previous week always sits above newer ones.
  """
  def week_segments(events, %Date{} = week_start) do
    week_end = Date.add(week_start, 6)

    {segments, lanes} =
      events
      |> Enum.filter(&overlaps?(&1, week_start, week_end))
      |> Enum.sort_by(&sort_key/1)
      |> Enum.map_reduce([], fn event, lanes ->
        col = max(Date.diff(event.starts_on, week_start), 0) + 1
        last_col = min(Date.diff(event.ends_on, week_start), 6) + 1
        {lane, lanes} = claim_lane(lanes, col, last_col)

        segment = %{
          event: event,
          col: col,
          span: last_col - col + 1,
          lane: lane,
          starts_here?: Date.compare(event.starts_on, week_start) != :lt,
          ends_here?: Date.compare(event.ends_on, week_end) != :gt
        }

        {segment, lanes}
      end)

    {segments, length(lanes)}
  end

  defp overlaps?(event, week_start, week_end) do
    Date.compare(event.starts_on, week_end) != :gt and
      Date.compare(event.ends_on, week_start) != :lt
  end

  defp sort_key(event) do
    {Date.to_gregorian_days(event.starts_on), -Date.diff(event.ends_on, event.starts_on),
     event.id}
  end

  # `lanes` holds the last occupied column of each lane. Segments arrive sorted
  # by start, so a lane is free once its last column is left of the new start.
  defp claim_lane(lanes, col, last_col) do
    case Enum.find_index(lanes, &(&1 < col)) do
      nil -> {length(lanes), lanes ++ [last_col]}
      lane -> {lane, List.replace_at(lanes, lane, last_col)}
    end
  end
end
