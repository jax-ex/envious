defmodule Envious do
  alias Envious.Parser

  def parse(str) do
    with {:ok, parsed, _remaining, _idk?, _line_tuple, _char} = Parser.parse(str) do
      {:ok,
       Enum.chunk_every(parsed, 2)
       |> Enum.reduce(%{}, fn [key, val], acc ->
         Map.put(acc, key, val)
       end)}
    end
  end
end
