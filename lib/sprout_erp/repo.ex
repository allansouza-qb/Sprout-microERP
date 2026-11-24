defmodule SproutErp.Repo do
  use Ecto.Repo,
    otp_app: :sprout_erp,
    adapter: Ecto.Adapters.Postgres
end
