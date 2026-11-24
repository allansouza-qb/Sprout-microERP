defmodule SproutErpWeb.ChannelCase do
  @moduledoc "Test case for channels: sets up the socket endpoint and the SQL sandbox."
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import SproutErpWeb.ChannelCase

      @endpoint SproutErpWeb.Endpoint
    end
  end

  setup tags do
    SproutErp.DataCase.setup_sandbox(tags)
    :ok
  end
end
