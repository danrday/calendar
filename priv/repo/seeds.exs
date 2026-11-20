# Sample events for development:
#
#     mix run priv/repo/seeds.exs

alias TeamCalendar.Events

month = Date.beginning_of_month(Date.utc_today())
day = fn n -> Date.add(month, n - 1) end

for {title, from, to, color} <- [
      {"hi", 15, 18, "purple"},
      {"New Event", 16, 17, "purple"},
      {"hello", 16, 17, "purple"},
      {"Release freeze", 19, 24, "red"},
      {"Design review", 4, 4, "blue"},
      {"Offsite", 9, 11, "green"}
    ] do
  {:ok, _event} =
    Events.create_event(%{title: title, starts_on: day.(from), ends_on: day.(to), color: color})
end
