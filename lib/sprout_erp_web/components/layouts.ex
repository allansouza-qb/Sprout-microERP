defmodule SproutErpWeb.Layouts do
  @moduledoc "HTML document around the single-page app (see layouts/root.html.heex)."
  use SproutErpWeb, :html

  embed_templates "layouts/*"
end
