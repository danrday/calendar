defmodule TeamCalendarWeb.CalendarLive do
  use TeamCalendarWeb, :live_view

  alias TeamCalendar.Events
  alias TeamCalendar.Events.Event
  alias TeamCalendar.MonthLayout

  # Lanes shown per week before the rest collapse into "+N more".
  @max_lanes 4

  @bar_colors %{
    "purple" => "bg-purple-500/20 text-purple-950 hover:bg-purple-500/35 dark:text-purple-100",
    "blue" => "bg-blue-500/20 text-blue-950 hover:bg-blue-500/35 dark:text-blue-100",
    "green" => "bg-green-500/20 text-green-950 hover:bg-green-500/35 dark:text-green-100",
    "orange" => "bg-orange-500/20 text-orange-950 hover:bg-orange-500/35 dark:text-orange-100",
    "red" => "bg-red-500/20 text-red-950 hover:bg-red-500/35 dark:text-red-100",
    "gray" => "bg-gray-500/20 text-gray-950 hover:bg-gray-500/35 dark:text-gray-100"
  }

  @dot_colors %{
    "purple" => "bg-purple-500",
    "blue" => "bg-blue-500",
    "green" => "bg-green-500",
    "orange" => "bg-orange-500",
    "red" => "bg-red-500",
    "gray" => "bg-gray-500"
  }

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Events.subscribe()

    {:ok,
     assign(socket,
       today: today(socket),
       events: [],
       expanded: MapSet.new(),
       event: nil,
       form: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    month = parse_month(params, socket.assigns.today)

    {:noreply,
     socket
     |> assign(
       month: month,
       expanded: MapSet.new(),
       page_title: Calendar.strftime(month, "%B %Y")
     )
     |> load_events()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="calendar" class="flex h-full flex-col">
        <header class="flex items-center justify-between gap-4 px-4 py-3">
          <h1 id="month-title" class="text-2xl tracking-tight">
            <span class="font-semibold">{Calendar.strftime(@month, "%B")}</span>
            <span class="font-light opacity-60">{@month.year}</span>
          </h1>
          <nav class="flex items-center gap-1">
            <Layouts.theme_toggle />
            <.link
              id="prev-month"
              patch={month_path(Date.shift(@month, month: -1))}
              aria-label="Previous month"
              class="ml-3 grid size-8 place-items-center rounded-md border border-base-300 transition-colors hover:bg-base-200"
            >
              <.icon name="hero-chevron-left" class="size-4" />
            </.link>
            <.link
              id="today"
              patch={month_path(@today)}
              class="grid h-8 place-items-center rounded-md border border-base-300 px-3 text-sm font-medium transition-colors hover:bg-base-200"
            >
              Today
            </.link>
            <.link
              id="next-month"
              patch={month_path(Date.shift(@month, month: 1))}
              aria-label="Next month"
              class="grid size-8 place-items-center rounded-md border border-base-300 transition-colors hover:bg-base-200"
            >
              <.icon name="hero-chevron-right" class="size-4" />
            </.link>
          </nav>
        </header>

        <div class="grid grid-cols-7 border-b border-base-300 text-right text-sm opacity-60">
          <div :for={name <- ~w(Sun Mon Tue Wed Thu Fri Sat)} class="px-2 pb-1">{name}</div>
        </div>

        <div id="weeks" class="flex min-h-0 flex-1 flex-col overflow-y-auto">
          <div
            :for={week <- @weeks}
            id={"week-#{week.start}"}
            class="grid min-h-32 flex-1 grid-cols-7 border-b border-base-300"
            style={"grid-template-rows: 2.25rem repeat(#{week.rows}, 1.5rem) 1fr"}
          >
            <button
              :for={{day, col} <- Enum.with_index(week.days, 1)}
              id={"day-#{day}"}
              type="button"
              phx-click="new_event"
              phx-value-date={day}
              aria-label={"New event on #{Calendar.strftime(day, "%B %-d")}"}
              style={"grid-column: #{col}; grid-row: 1 / -1"}
              class={[
                "flex cursor-pointer items-start justify-end p-1 text-sm transition-colors hover:bg-base-200",
                col < 7 && "border-r border-base-300",
                col in [1, 7] && "bg-base-200/40"
              ]}
            >
              <span class={[
                "grid size-7 place-items-center rounded-full",
                day == @today && "bg-red-500 font-semibold text-white",
                day != @today && day.month != @month.month && "opacity-35"
              ]}>
                {day.day}
              </span>
            </button>

            <button
              :for={segment <- week.segments}
              id={"event-#{segment.event.id}-#{week.start}"}
              type="button"
              phx-click="edit_event"
              phx-value-id={segment.event.id}
              style={"grid-column: #{segment.col} / span #{segment.span}; grid-row: #{segment.lane + 2}"}
              class={[
                "flex h-[1.375rem] min-w-0 cursor-pointer items-center gap-1.5 px-2 text-left text-xs font-medium transition-colors",
                segment.starts_here? && "ml-1 rounded-l-full",
                segment.ends_here? && "mr-1 rounded-r-full",
                bar_color(segment.event.color)
              ]}
            >
              <span
                :if={segment.starts_here?}
                class={["size-2 shrink-0 rounded-full", dot_color(segment.event.color)]}
              ></span>
              <span class="truncate">{segment.event.title}</span>
            </button>

            <button
              :for={{col, count} <- week.more}
              id={"more-#{Date.add(week.start, col - 1)}"}
              type="button"
              phx-click="expand_week"
              phx-value-week={week.start}
              style={"grid-column: #{col}; grid-row: #{week.rows + 1}"}
              class="mx-1 h-[1.375rem] cursor-pointer truncate rounded-full px-2 text-left text-xs opacity-60 transition hover:bg-base-200 hover:opacity-100"
            >
              +{count} more
            </button>
          </div>
        </div>
      </div>

      <div
        :if={@form}
        id="event-modal"
        class="fixed inset-0 z-50 grid place-items-center p-4"
        phx-window-keydown="close_form"
        phx-key="escape"
      >
        <div id="event-modal-backdrop" class="absolute inset-0 bg-black/30" phx-click="close_form">
        </div>
        <div
          role="dialog"
          aria-modal="true"
          aria-label={if(@event.id, do: "Edit event", else: "New event")}
          class="relative w-full max-w-sm rounded-xl border border-base-300 bg-base-100 p-5 shadow-2xl"
        >
          <.form for={@form} id="event-form" phx-change="validate" phx-submit="save">
            <.input
              field={@form[:title]}
              type="text"
              label="Title"
              placeholder="New Event"
              autocomplete="off"
              phx-mounted={JS.focus()}
            />
            <div class="grid grid-cols-2 gap-3">
              <.input field={@form[:starts_on]} type="date" label="Starts" />
              <.input field={@form[:ends_on]} type="date" label="Ends" />
            </div>
            <.input
              field={@form[:color]}
              type="select"
              label="Color"
              options={Enum.map(Event.colors(), &{String.capitalize(&1), &1})}
            />
            <.input field={@form[:notes]} type="textarea" label="Notes" />

            <div class="mt-4 flex items-center gap-2">
              <button
                :if={@event.id}
                id="delete-event"
                type="button"
                phx-click="delete"
                data-confirm="Delete this event for everyone?"
                class="cursor-pointer rounded-md px-3 py-1.5 text-sm font-medium text-red-600 transition-colors hover:bg-red-500/10"
              >
                Delete
              </button>
              <button
                id="cancel-event"
                type="button"
                phx-click="close_form"
                class="ml-auto cursor-pointer rounded-md px-3 py-1.5 text-sm font-medium transition-colors hover:bg-base-200"
              >
                Cancel
              </button>
              <button
                id="save-event"
                type="submit"
                class="cursor-pointer rounded-md bg-red-500 px-3 py-1.5 text-sm font-semibold text-white transition-colors hover:bg-red-600"
              >
                Save
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("new_event", %{"date" => date}, socket) do
    case Date.from_iso8601(date) do
      {:ok, date} -> {:noreply, open_form(socket, %Event{starts_on: date, ends_on: date})}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("edit_event", %{"id" => id}, socket) do
    with {id, ""} <- Integer.parse(id),
         %Event{} = event <- Events.get_event(id) do
      {:noreply, open_form(socket, event)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("validate", %{"event" => params}, %{assigns: %{event: %Event{}}} = socket) do
    changeset =
      socket.assigns.event
      |> Events.change_event(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"event" => params}, %{assigns: %{event: %Event{}}} = socket) do
    result =
      case socket.assigns.event do
        %Event{id: nil} -> Events.create_event(params)
        event -> Events.update_event(event, params)
      end

    # The grid itself refreshes from the broadcast, like every other client.
    case result do
      {:ok, _event} -> {:noreply, close_form(socket)}
      {:error, changeset} -> {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete", _params, %{assigns: %{event: %Event{id: id} = event}} = socket)
      when not is_nil(id) do
    {:ok, _event} = Events.delete_event(event)
    {:noreply, close_form(socket)}
  end

  def handle_event("close_form", _params, socket), do: {:noreply, close_form(socket)}

  def handle_event("expand_week", %{"week" => week}, socket) do
    case Date.from_iso8601(week) do
      {:ok, week} ->
        {:noreply, socket |> update(:expanded, &MapSet.put(&1, week)) |> assign_weeks()}

      _ ->
        {:noreply, socket}
    end
  end

  # A form event that arrives after the form was closed, e.g. by a remote delete.
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:event_saved, _event}, socket), do: {:noreply, load_events(socket)}

  def handle_info({:event_deleted, deleted}, socket) do
    socket =
      case socket.assigns.event do
        %Event{id: id} when id == deleted.id ->
          socket |> close_form() |> put_flash(:info, "Someone else deleted that event.")

        _ ->
          socket
      end

    {:noreply, load_events(socket)}
  end

  defp open_form(socket, event) do
    assign(socket, event: event, form: to_form(Events.change_event(event)))
  end

  defp close_form(socket), do: assign(socket, event: nil, form: nil)

  defp load_events(socket) do
    {first, last} = MonthLayout.grid_range(socket.assigns.month)

    socket
    |> assign(events: Events.list_events_between(first, last))
    |> assign_weeks()
  end

  defp assign_weeks(socket) do
    %{month: month, events: events, expanded: expanded} = socket.assigns
    assign(socket, weeks: Enum.map(MonthLayout.weeks(month), &build_week(&1, events, expanded)))
  end

  defp build_week(week_start, events, expanded) do
    {segments, lanes} = MonthLayout.week_segments(events, week_start)
    week = %{start: week_start, days: Enum.map(0..6, &Date.add(week_start, &1))}

    if lanes <= @max_lanes or MapSet.member?(expanded, week_start) do
      Map.merge(week, %{segments: segments, rows: max(lanes, 1), more: []})
    else
      # The last visible row is given over to the per-day "+N more" links.
      {visible, hidden} = Enum.split_with(segments, &(&1.lane < @max_lanes - 1))

      more =
        hidden
        |> Enum.flat_map(&Enum.to_list(&1.col..(&1.col + &1.span - 1)))
        |> Enum.frequencies()
        |> Enum.sort()

      Map.merge(week, %{segments: visible, rows: @max_lanes, more: more})
    end
  end

  defp parse_month(%{"year" => year, "month" => month}, today) do
    with {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         {:ok, date} <- Date.new(year, month, 1) do
      date
    else
      _ -> Date.beginning_of_month(today)
    end
  end

  defp parse_month(_params, today), do: Date.beginning_of_month(today)

  # The browser reports its UTC offset on connect so "today" matches the
  # viewer's wall clock; the initial static render falls back to UTC.
  defp today(socket) do
    offset =
      case connected?(socket) && get_connect_params(socket) do
        %{"tz_offset" => offset} when is_integer(offset) and offset in -840..840 -> offset
        _ -> 0
      end

    DateTime.utc_now() |> DateTime.add(offset, :minute) |> DateTime.to_date()
  end

  defp month_path(date), do: ~p"/month/#{date.year}/#{date.month}"

  defp bar_color(color), do: Map.get(@bar_colors, color, @bar_colors["purple"])
  defp dot_color(color), do: Map.get(@dot_colors, color, @dot_colors["purple"])
end
