defmodule SproutErp.Money do
  @moduledoc "USD amounts as integer cents: formatting for messages and parsing of typed values."

  def format(nil), do: "—"

  def format(cents) when is_integer(cents),
    do: sign(cents) <> "$" <> group(div(abs(cents), 100)) <> "." <> pad(rem(abs(cents), 100))

  def to_cents(nil), do: nil
  def to_cents(""), do: nil

  def to_cents(str) when is_binary(str) do
    case Float.parse(String.replace(str, ~r/[$,\s]/, "")) do
      {f, _} -> round(f * 100)
      :error -> nil
    end
  end

  def to_cents(n) when is_number(n), do: round(n * 100)

  defp sign(c) when c < 0, do: "−"
  defp sign(_), do: ""
  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  defp group(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end
