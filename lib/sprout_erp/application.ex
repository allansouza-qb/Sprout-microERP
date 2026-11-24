defmodule SproutErp.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SproutErpWeb.Telemetry,
      SproutErp.Repo,
      {DNSCluster, query: Application.get_env(:sprout_erp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SproutErp.PubSub},
      # Start a worker by calling: SproutErp.Worker.start_link(arg)
      # {SproutErp.Worker, arg},
      # Start to serve requests, typically the last entry
      SproutErpWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SproutErp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SproutErpWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
