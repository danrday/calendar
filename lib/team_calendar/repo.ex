defmodule TeamCalendar.Repo do
  use Ecto.Repo,
    otp_app: :team_calendar,
    adapter: Ecto.Adapters.Postgres
end
