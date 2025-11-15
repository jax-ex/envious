defmodule Envious.Parser do
  @moduledoc """
  Parser for .env files using NimbleParsec.

  This parser handles the common .env file format with support for:
  - Simple key-value pairs: `KEY=value`
  - Export prefix: `export KEY=value`
  - Comments: `# this is a comment`
  - Inline comments: `KEY=value # comment`
  - Multi-line files

  ## Parser Structure

  The parser is built using combinators that define small parsing units
  which are then combined to parse complete .env files. The main flow is:

  1. Skip any leading whitespace/newlines
  2. Repeatedly parse either:
     - A key-value pair (KEY=VALUE)
     - A comment line (# ...)
  3. Each line may be terminated by a newline

  ## Example

      iex> Envious.Parser.parse("FOO=bar")
      {:ok, ["FOO", "bar"], "", %{}, {1, 0}, 7}

      iex> Envious.Parser.parse("export KEY=value\\n# comment\\nFOO=bar")
      {:ok, ["KEY", "value", "FOO", "bar"], "", %{}, ...}
  """

  import NimbleParsec

  # Character codes for common separators and control characters
  @horizontal_tab 0x0009
  @newline 0x000A
  @carriage_return 0x000D
  @space 0x0020
  @unicode_bom 0xFEFF
  @equals 0x003D

  # Match any single unicode character (used for consuming comment text)
  any_unicode = utf8_char([])

  # Unicode BOM (Byte Order Mark) - sometimes appears at start of UTF-8 files
  unicode_bom = utf8_char([@unicode_bom])

  # The equals sign that separates keys from values
  equals = ascii_char([@equals])

  # Line terminators: \n or \r\n (handles both Unix and Windows line endings)
  line_terminator =
    choice([
      ascii_char([@newline]),
      # Windows-style \r\n
      ascii_char([@carriage_return])
      |> optional(ascii_char([@newline]))
    ])

  # Whitespace characters: tabs and spaces (not newlines)
  whitespace =
    ascii_char([
      @horizontal_tab,
      @space
    ])

  # Characters to ignore when parsing:
  # - Unicode BOM at start of file
  # - Whitespace (tabs, spaces)
  # - Line terminators (newlines)
  ignored =
    choice([
      unicode_bom,
      whitespace,
      line_terminator
    ])

  # The "export" keyword followed by required whitespace
  # Example: "export " in "export KEY=value"
  export = string("export") |> concat(times(whitespace, min: 1))

  # Comment: starts with # and continues until end of line
  # Uses repeat_while with a custom function to stop at newlines
  comment =
    string("#")
    |> repeat_while(any_unicode, {:not_line_terminator, []})

  # Variable name: must start with letter or underscore, can contain letters, digits, underscores
  # Examples: FOO, API_KEY, database_url
  var_name =
    utf8_string([?A..?Z, ?a..?z, ?_], min: 1)

  # Value characters: Accept most printable ASCII except:
  # - Newline (\n) and carriage return (\r) - these end the value
  # - Hash (#) - this starts an inline comment
  #
  # Character ranges:
  # - ?\s..?" is space (0x20) through double-quote (0x22), excluding # (0x23)
  # - ?$..?~ is dollar (0x24) through tilde (0x7E), which includes A-Z, a-z, 0-9, and symbols
  value_char =
    utf8_char([
      # Space (32) through double-quote (34), which excludes hash (35)
      ?\s..?",
      # Dollar sign (36) through tilde (126) - includes all alphanumeric and symbols
      ?$..?~
    ])

  # Parse the value portion after the = sign
  # - Collect 1 or more value characters
  # - Convert the character list to a string
  # - Trim whitespace from both ends (handles inline comments: "value # comment")
  val =
    times(value_char, min: 1)
    |> reduce({List, :to_string, []})
    |> post_traverse(:trim_value)

  # Key-value pair parser: [export] KEY=VALUE[newline]
  #
  # Structure:
  # 1. Optionally ignore the "export" keyword
  # 2. Capture the variable name
  # 3. Ignore the equals sign
  # 4. Capture the value
  # 5. Ignore optional trailing newline
  #
  # Examples:
  # - "KEY=value" -> ["KEY", "value"]
  # - "export FOO=bar" -> ["FOO", "bar"]
  # - "KEY=value # comment" -> ["KEY", "value"] (trimmed)
  key_value =
    optional(ignore(export))
    |> concat(var_name)
    |> ignore(equals)
    |> concat(val)
    |> ignore(optional(line_terminator))

  # Comment line parser: # comment text [newline]
  #
  # Comments are completely ignored and don't contribute to the parse result
  comment_line =
    comment
    |> ignore(optional(line_terminator))

  # Main parser entry point
  #
  # Structure:
  # 1. Ignore any leading whitespace/newlines
  # 2. Repeatedly parse either:
  #    - A key-value pair (contributes to result)
  #    - A comment line (ignored)
  #
  # Returns: {:ok, [key1, value1, key2, value2, ...], remaining, context, position, offset}
  #
  # The flat list of alternating keys and values is later chunked by 2 in the
  # Envious module to create a map.
  defparsec :parse, ignore(times(ignored, min: 0)) |> repeat(choice([key_value, ignore(comment_line)]))

  ## Helper Functions

  # Callback for repeat_while that stops when encountering a line terminator
  # Used by the comment parser to consume characters until end of line
  #
  # Returns:
  # - {:halt, context} when a newline or carriage return is found
  # - {:cont, context} to continue consuming characters
  defp not_line_terminator(<<?\n, _::binary>>, context, _, _), do: {:halt, context}
  defp not_line_terminator(<<?\r, _::binary>>, context, _, _), do: {:halt, context}
  defp not_line_terminator(_, context, _, _), do: {:cont, context}

  # Post-traversal callback to trim whitespace from parsed values
  #
  # This is used to remove trailing whitespace before inline comments.
  # Example: "value  # comment" becomes "value"
  #
  # Parameters:
  # - rest: Remaining input after parsing
  # - [value]: The parsed value (as a single-element list from the accumulator)
  # - context: Parser context
  # - _line, _offset: Position information (unused)
  #
  # Returns: {rest, [trimmed_value], context}
  #
  # Note: We must return `rest` (not an empty list) to allow the parser to
  # continue processing remaining input. Returning [] would consume all input.
  defp trim_value(rest, [value], context, _line, _offset) when is_binary(value) do
    {rest, [String.trim(value)], context}
  end

  # Fallback clause for trim_value when accumulator doesn't match expected pattern
  defp trim_value(rest, acc, context, _line, _offset) do
    {rest, acc, context}
  end
end
