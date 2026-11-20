defmodule TeamCalendarWeb.CalendarLiveTest do
  use TeamCalendarWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TeamCalendar.Events

  defp create_event(attrs) do
    {:ok, event} =
      Events.create_event(Enum.into(attrs, %{title: "Launch", color: "purple"}))

    event
  end

  test "shows the requested month and navigates between months", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/month/2026/11")

    assert has_element?(view, "#month-title", "November")
    assert has_element?(view, "#day-2026-11-01")
    assert has_element?(view, "#day-2026-12-12")

    view |> element("#next-month") |> render_click()
    assert_patch(view, ~p"/month/2026/12")
    assert has_element?(view, "#month-title", "December")

    view |> element("#prev-month") |> render_click()
    assert_patch(view, ~p"/month/2026/11")
  end

  test "falls back to the current month for a nonsense URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/month/2026/13")
    assert has_element?(view, "#month-title", Calendar.strftime(Date.utc_today(), "%B"))
  end

  test "creates an event by clicking a day", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/month/2026/11")

    refute has_element?(view, "#event-form")
    view |> element("#day-2026-11-16") |> render_click()
    assert has_element?(view, "#event-form")

    view
    |> form("#event-form", event: %{title: "Ship v1", ends_on: "2026-11-18"})
    |> render_submit()

    refute has_element?(view, "#event-form")
    assert has_element?(view, "#week-2026-11-15 button", "Ship v1")
  end

  test "rejects an end date before the start date", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/month/2026/11")
    view |> element("#day-2026-11-16") |> render_click()

    view
    |> form("#event-form", event: %{title: "Backwards", ends_on: "2026-11-10"})
    |> render_submit()

    assert has_element?(view, "#event-form")
    assert Events.list_events_between(~D[2026-11-01], ~D[2026-11-30]) == []
  end

  test "draws one bar per week for an event that crosses a week boundary", %{conn: conn} do
    event = create_event(starts_on: ~D[2026-11-19], ends_on: ~D[2026-11-24])
    {:ok, view, _html} = live(conn, ~p"/month/2026/11")

    assert has_element?(view, "#event-#{event.id}-2026-11-15")
    assert has_element?(view, "#event-#{event.id}-2026-11-22")
    refute has_element?(view, "#event-#{event.id}-2026-11-29")
  end

  test "edits and deletes an event", %{conn: conn} do
    event = create_event(starts_on: ~D[2026-11-16], ends_on: ~D[2026-11-16])
    {:ok, view, _html} = live(conn, ~p"/month/2026/11")

    view |> element("#event-#{event.id}-2026-11-15") |> render_click()
    view |> form("#event-form", event: %{title: "Renamed"}) |> render_submit()
    assert has_element?(view, "#event-#{event.id}-2026-11-15", "Renamed")

    view |> element("#event-#{event.id}-2026-11-15") |> render_click()
    view |> element("#delete-event") |> render_click()
    refute has_element?(view, "#event-#{event.id}-2026-11-15")
  end

  test "shows changes made by other people without a reload", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/month/2026/11")

    event =
      create_event(title: "From a coworker", starts_on: ~D[2026-11-05], ends_on: ~D[2026-11-06])

    assert has_element?(view, "#event-#{event.id}-2026-11-01", "From a coworker")

    {:ok, _event} = Events.delete_event(event)
    refute has_element?(view, "#event-#{event.id}-2026-11-01")
  end

  test "closes the form when someone else deletes the event being edited", %{conn: conn} do
    event = create_event(starts_on: ~D[2026-11-16], ends_on: ~D[2026-11-16])
    {:ok, view, _html} = live(conn, ~p"/month/2026/11")

    view |> element("#event-#{event.id}-2026-11-15") |> render_click()
    assert has_element?(view, "#event-form")

    {:ok, _event} = Events.delete_event(event)
    refute has_element?(view, "#event-form")
  end

  test "collapses a crowded week into '+N more' and expands it on click", %{conn: conn} do
    events =
      for n <- 1..6 do
        create_event(title: "Event #{n}", starts_on: ~D[2026-11-16], ends_on: ~D[2026-11-16])
      end

    {:ok, view, _html} = live(conn, ~p"/month/2026/11")

    assert has_element?(view, "#more-2026-11-16", "+3 more")
    refute has_element?(view, "#event-#{List.last(events).id}-2026-11-15")

    view |> element("#more-2026-11-16") |> render_click()

    refute has_element?(view, "#more-2026-11-16")
    assert has_element?(view, "#event-#{List.last(events).id}-2026-11-15")

    # An expanded week stays expanded as events are added, so it must offer a way back.
    assert has_element?(view, "#less-2026-11-15")
    refute has_element?(view, "#less-2026-11-08")

    view |> element("#less-2026-11-15") |> render_click()

    assert has_element?(view, "#more-2026-11-16", "+3 more")
    refute has_element?(view, "#less-2026-11-15")
  end

  describe "drag gestures" do
    test "dragging across days opens a new event spanning them", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/month/2026/11")

      render_hook(view, "new_event", %{"start" => "2026-11-25", "end" => "2026-11-27"})

      assert has_element?(view, "#event-form input[name='event[starts_on]'][value='2026-11-25']")
      assert has_element?(view, "#event-form input[name='event[ends_on]'][value='2026-11-27']")

      view |> form("#event-form", event: %{title: "Three days"}) |> render_submit()

      assert [%{starts_on: ~D[2026-11-25], ends_on: ~D[2026-11-27]}] =
               Events.list_events_between(~D[2026-11-25], ~D[2026-11-27])

      assert_push_event(view, "clear_drag", %{})
    end

    test "dragging backwards still gives an ordered range", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/month/2026/11")

      render_hook(view, "new_event", %{"start" => "2026-11-27", "end" => "2026-11-25"})

      assert has_element?(view, "#event-form input[name='event[starts_on]'][value='2026-11-25']")
      assert has_element?(view, "#event-form input[name='event[ends_on]'][value='2026-11-27']")
    end

    test "dropping a bar on another day moves the whole event", %{conn: conn} do
      event = create_event(starts_on: ~D[2026-11-16], ends_on: ~D[2026-11-17])
      {:ok, view, _html} = live(conn, ~p"/month/2026/11")

      render_hook(view, "move_event", %{"id" => "#{event.id}", "days" => 8})

      assert_push_event(view, "clear_drag", %{})
      refute has_element?(view, "#event-#{event.id}-2026-11-15")
      assert has_element?(view, "#event-#{event.id}-2026-11-22[data-start='2026-11-24']")
      assert %{starts_on: ~D[2026-11-24], ends_on: ~D[2026-11-25]} = Events.get_event(event.id)
    end

    test "moving an event that no longer exists clears the preview", %{conn: conn} do
      event = create_event(starts_on: ~D[2026-11-16], ends_on: ~D[2026-11-17])
      {:ok, view, _html} = live(conn, ~p"/month/2026/11")
      {:ok, _event} = Events.delete_event(event)

      render_hook(view, "move_event", %{"id" => "#{event.id}", "days" => 1})

      assert_push_event(view, "clear_drag", %{})
      assert Events.get_event(event.id) == nil
    end
  end
end
