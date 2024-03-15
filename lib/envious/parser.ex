defmodule Envious.Parser do
  import NimbleParsec

  key =
    empty()
    |> utf8_string([{:not, ?=}], 1)
    |> repeat()
    |> reduce({Enum, :join, [""]})

  val =
    ignore(string("="))
    |> repeat(utf8_string([], 1))
    |> reduce({Enum, :join, [""]})

  defparsec :parse, key |> concat(val)
end
