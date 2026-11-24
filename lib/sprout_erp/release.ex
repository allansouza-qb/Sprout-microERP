defmodule SproutErp.Release do
  @moduledoc """
  Database tasks for a release, where Mix is not available:

      bin/sprout_erp eval "SproutErp.Release.migrate()"
      bin/sprout_erp eval "SproutErp.Release.setup_demo()"
  """
  @app :sprout_erp

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Prepares a demo deployment: runs the migrations and, when the database has
  no units yet, loads the demo data. Safe to run on every start: an existing
  database is left as it is.
  """
  def setup_demo do
    migrate()
    # The seeds go through the contexts, which need the whole application
    # (repository and PubSub) running; the web server is not started here.
    {:ok, _} = Application.ensure_all_started(@app)

    if SproutErp.Repo.exists?(SproutErp.Inventory.Unit) do
      IO.puts("Demo data already present; nothing to seed.")
    else
      Code.eval_file(Application.app_dir(@app, "priv/repo/seeds.exs"))
    end

    :ok
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
