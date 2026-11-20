defmodule TeamCalendar.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TeamCalendarWeb.Telemetry,
      TeamCalendar.Repo,
      {DNSCluster, query: Application.get_env(:team_calendar, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TeamCalendar.PubSub},
      # Start a worker by calling: TeamCalendar.Worker.start_link(arg)
      # {TeamCalendar.Worker, arg},
      # Start to serve requests, typically the last entry
      TeamCalendarWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TeamCalendar.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TeamCalendarWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
