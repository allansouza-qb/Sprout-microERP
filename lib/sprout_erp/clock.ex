defmodule SproutErp.Clock do
  @moduledoc """
  The company's wall clock.

  The time zone is configured in one place (`config/config.exs`):

      config :sprout_erp, :time_zone, "America/Sao_Paulo"

  Timestamps are stored in UTC. Anything treated as a business date ("today",
  sold on, listed on), any date/time shown to people and the dashboard
  greeting go through this module. Functions take an optional UTC instant so
  they can be tested deterministically.
  """

  def time_zone, do: Application.fetch_env!(:sprout_erp, :time_zone)

  @doc "Current time in the company zone."
  def now(utc_now \\ DateTime.utc_now()), do: DateTime.shift_zone!(utc_now, time_zone())

  @doc "Today's date in the company zone."
  def today(utc_now \\ DateTime.utc_now()), do: utc_now |> now() |> DateTime.to_date()

  @doc "Converts a stored UTC timestamp to the company zone for display."
  def local(%DateTime{} = utc), do: DateTime.shift_zone!(utc, time_zone())

  @doc "A UTC instant for a wall-clock date and time in the company zone."
  def utc_at(%Date{} = date, %Time{} = time) do
    case DateTime.new(date, time, time_zone()) do
      {:ok, dt} -> dt
      {:ambiguous, first, _second} -> first
      {:gap, _before, just_after} -> just_after
    end
    |> DateTime.shift_zone!("Etc/UTC")
  end

  @doc "Greeting for the current hour in the company zone."
  def greeting(utc_now \\ DateTime.utc_now()) do
    case now(utc_now).hour do
      h when h in 5..11 -> "Good morning"
      h when h in 12..17 -> "Good afternoon"
      _ -> "Good evening"
    end
  end
end
