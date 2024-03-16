defmodule Envious.Parser do
  import NimbleParsec

  @horizontal_tab 0x0009
  @newline 0x000A
  @carriage_return 0x000D
  @space 0x0020
  @unicode_bom 0xFEFF
  @equals 0x003D

  unicode_bom = utf8_char([@unicode_bom])

  equals = ascii_char([@equals])

  line_terminator =
    choice([
      ascii_char([@newline]),
      ascii_char([@carriage_return])
      |> optional(ascii_char([@newline]))
    ])

  whitespace =
    ascii_char([
      @horizontal_tab,
      @space
    ])

  ignored =
    choice([
      unicode_bom,
      whitespace,
      line_terminator,
      equals
    ])

  var_name =
    empty()
    |> concat(utf8_string([?A..?Z, ?a..?z, ?_], min: 1))

  val =
    empty()
    |> concat(utf8_string([?a..?z], min: 1))

  defparsec :parse, choice([ignore(ignored), var_name, val]) |> repeat()
end
