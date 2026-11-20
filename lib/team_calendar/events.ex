defmodule TeamCalendar.Events do
  @moduledoc """
  The shared calendar's events. Every write is broadcast over PubSub so that
  all connected calendars stay in sync.
  """
  import Ecto.Query

  alias TeamCalendar.Events.Event
  alias TeamCalendar.Repo

  @topic "events"

  @doc """
  Subscribes the caller to `{:event_saved, event}` and `{:event_deleted, event}` messages.
  """
  def subscribe, do: Phoenix.PubSub.subscribe(TeamCalendar.PubSub, @topic)

  @doc """
  Lists events that overlap the inclusive date range `first..last`.
  """
  def list_events_between(%Date{} = first, %Date{} = last) do
    Repo.all(
      from e in Event,
        where: e.starts_on <= ^last and e.ends_on >= ^first,
        order_by: [e.starts_on, e.id]
    )
  end

  def get_event(id), do: Repo.get(Event, id)

  def change_event(%Event{} = event, attrs \\ %{}), do: Event.changeset(event, attrs)

  def create_event(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:event_saved)
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update(stale_error_field: :title, stale_error_message: "was deleted by someone else")
    |> broadcast(:event_saved)
  end

  def delete_event(%Event{} = event) do
    event
    |> Repo.delete(allow_stale: true)
    |> broadcast(:event_deleted)
  end

  defp broadcast({:ok, event} = result, message) do
    Phoenix.PubSub.broadcast(TeamCalendar.PubSub, @topic, {message, event})
    result
  end

  defp broadcast(result, _message), do: result
end
