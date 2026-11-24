defmodule SproutErp.CSV do
  @moduledoc """
  Minimal RFC 4180 CSV encoder for exports (no dependency).

  * text cells containing `,` `"` or line breaks are quoted, quotes doubled;
  * text starting with `=`, `+`, `-`, `@`, tab or CR gets a leading `'` so
    spreadsheet apps do not evaluate it as a formula (CSV injection);
  * `{:num, string}` cells are written as-is (numbers are never prefixed).
  """

  def encode(rows), do: Enum.map_join(rows, "", &(row(&1) <> "\r\n"))

  @doc "Cents as a plain decimal number cell, e.g. 123456 -> 1234.56."
  def money(nil), do: nil

  def money(cents) when is_integer(cents),
    do: {:num, :erlang.float_to_binary(cents / 100, decimals: 2)}

  defp row(cells), do: Enum.map_join(cells, ",", &cell/1)

  defp cell(nil), do: ""
  defp cell({:num, s}), do: s
  defp cell(n) when is_integer(n), do: Integer.to_string(n)
  defp cell(true), do: "true"
  defp cell(false), do: "false"
  defp cell(%Date{} = d), do: Date.to_iso8601(d)
  defp cell(v) when is_binary(v), do: v |> neutralize() |> quote_if_needed()
  defp cell(v), do: v |> to_string() |> cell()

  defp neutralize(<<c, _::binary>> = v) when c in [?=, ?+, ?-, ?@, ?\t, ?\r], do: "'" <> v
  defp neutralize(v), do: v

  defp quote_if_needed(v) do
    if String.contains?(v, [",", "\"", "\n", "\r"]),
      do: "\"" <> String.replace(v, "\"", "\"\"") <> "\"",
      else: v
  end
end
