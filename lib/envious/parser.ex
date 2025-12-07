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
      {:ok, [{"FOO", "bar"}], "", %{}, {1, 0}, 7}

      iex> Envious.Parser.parse("export KEY=value\\n# comment\\nFOO=bar")
      {:ok, [{"KEY", "value"}, {"FOO", "bar"}], "", %{}, ...}
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
  # Per POSIX shell syntax: [a-zA-Z_][a-zA-Z0-9_]*
  # Examples: FOO, API_KEY, database_url, KEY1, DB2_HOST
  var_name =
    utf8_char([?A..?Z, ?a..?z, ?_])
    |> concat(times(utf8_char([?A..?Z, ?a..?z, ?0..?9, ?_]), min: 0))
    |> reduce({List, :to_string, []})

  # Double quote character
  double_quote = ascii_char([?"])

  # Single quote character
  single_quote = ascii_char([?'])

  # Escape sequence: backslash followed by any character
  # This allows \n, \t, \", \\, etc.
  escape_sequence =
    string("\\")
    |> utf8_char([])

  # Regular character inside double-quoted strings (not backslash, not double-quote)
  double_quoted_regular_char =
    utf8_char([
      # Tab and newline
      @horizontal_tab,
      @newline,
      # Carriage return
      @carriage_return,
      # Space through exclamation (!), excluding double-quote (") and backslash (\)
      ?\s..?!,
      # Hash (#) through open-bracket ([), excluding backslash (\\)
      ?#..?[,
      # Close-bracket (]) through tilde (~)
      ?]..?~
    ])

  # Regular character inside single-quoted strings (not backslash, not single-quote)
  single_quoted_regular_char =
    utf8_char([
      # Tab and newline
      @horizontal_tab,
      @newline,
      # Carriage return
      @carriage_return,
      # Space through ampersand (&), excluding single-quote (') and backslash (\)
      ?\s..?&,
      # Open-paren (() through open-bracket ([), excluding backslash (\\)
      ?(..?[,
      # Close-bracket (]) through tilde (~)
      ?]..?~
    ])

  # Escaped dollar sign (for interpolation mode)
  # Converts \$ to a literal $ character tagged as a literal
  escaped_dollar =
    string("\\$")
    |> replace({:literal, "$"})

  # Variable interpolation: $VAR or ${VAR}
  # Returns the variable name tagged with :var for later resolution
  # ${VAR} is checked first because $VAR would match the $ in ${VAR}
  var_interpolation =
    choice([
      # ${VAR} format - braced variable reference
      ignore(string("${"))
      |> concat(var_name)
      |> ignore(string("}"))
      |> unwrap_and_tag(:var),
      # $VAR format - simple variable reference
      ignore(string("$"))
      |> concat(var_name)
      |> unwrap_and_tag(:var)
    ])

  # Content inside double quotes (non-interpolating mode): escape sequences or regular characters
  double_quoted_content =
    choice([
      escape_sequence,
      double_quoted_regular_char
    ])

  # Content inside double quotes (interpolating mode): escaped $, variables, escapes, or regular chars
  # Order matters: escaped_dollar must come before var_interpolation
  double_quoted_content_interpolated =
    choice([
      escaped_dollar,
      var_interpolation,
      escape_sequence,
      double_quoted_regular_char
    ])

  # Content inside single quotes: either escape sequences or regular characters
  # Single quotes do NOT allow variable interpolation (like shell behavior)
  single_quoted_content =
    choice([
      escape_sequence,
      single_quoted_regular_char
    ])

  # Double-quoted value (non-interpolating): "value with spaces"
  # Returns a plain string after processing escape sequences
  double_quoted_value =
    ignore(double_quote)
    |> times(double_quoted_content, min: 0)
    |> ignore(double_quote)
    |> reduce({List, :to_string, []})
    |> post_traverse(:process_escape_sequences)

  # Double-quoted value (interpolating): "value with $VAR interpolation"
  # Returns a list of tokens: {:literal, str} and {:var, name}
  double_quoted_value_interpolated =
    ignore(double_quote)
    |> times(double_quoted_content_interpolated, min: 0)
    |> ignore(double_quote)
    |> post_traverse(:build_token_list)

  # Single-quoted value: 'value with spaces'
  # - Handles escape sequences and regular characters
  # - Does NOT support variable interpolation (like shell behavior)
  single_quoted_value =
    ignore(single_quote)
    |> times(single_quoted_content, min: 0)
    |> ignore(single_quote)
    |> reduce({List, :to_string, []})
    |> post_traverse(:process_escape_sequences)

  # Single-quoted value for interpolation mode (still no interpolation - shell semantics)
  # Returns a single {:literal, str} token
  single_quoted_value_interpolated =
    ignore(single_quote)
    |> times(single_quoted_content, min: 0)
    |> ignore(single_quote)
    |> reduce({List, :to_string, []})
    |> post_traverse(:wrap_as_literal_token)

  # Value characters for unquoted values (non-interpolating mode)
  # Accepts most printable ASCII except: newline, carriage return, hash, quotes
  # INCLUDES $ as a regular character for backward compatibility
  unquoted_value_char =
    utf8_char([
      # Space (32) through exclamation (33), which excludes double-quote (34)
      ?\s..?!,
      # Dollar (36) through ampersand (38), which excludes hash (35) and single-quote (39)
      ?$..?&,
      # Open-paren (40) through tilde (126) - includes all alphanumeric and symbols
      ?(..?~
    ])

  # Value characters for unquoted values (interpolating mode)
  # Excludes $ and braces which have special meaning
  unquoted_value_char_interpolated =
    utf8_char([
      # Space (32) through exclamation (33), which excludes double-quote (34)
      ?\s..?!,
      # Percent (37) through ampersand (38), which excludes hash (35), dollar (36), and single-quote (39)
      ?%..?&,
      # Open-paren (40) through lowercase z (122), which excludes left-brace (123)
      ?(..?z,
      # Pipe (124) through tilde (126), which excludes right-brace (125)
      ?|..?~
    ])

  # Literal dollar sign when not followed by a valid variable name start
  # This allows $100 to remain as $100 instead of trying to interpolate
  literal_dollar =
    string("$")
    |> lookahead_not(utf8_char([?A..?Z, ?a..?z, ?_]))

  # Unquoted value content (interpolating mode): variable, literal $, or regular chars
  unquoted_value_content_interpolated =
    choice([
      var_interpolation,
      literal_dollar,
      unquoted_value_char_interpolated
    ])

  # Unquoted value (non-interpolating): plain string with trimming
  unquoted_value =
    times(unquoted_value_char, min: 0)
    |> reduce({List, :to_string, []})
    |> post_traverse(:trim_value)

  # Unquoted value (interpolating): returns list of tokens
  unquoted_value_interpolated =
    times(unquoted_value_content_interpolated, min: 0)
    |> post_traverse(:build_unquoted_token_list)

  # Parse the value portion after the = sign (non-interpolating mode)
  # Returns a plain string
  val =
    choice([
      double_quoted_value,
      single_quoted_value,
      unquoted_value
    ])

  # Parse the value portion after the = sign (interpolating mode)
  # Returns a list of tokens: {:literal, str} and {:var, name}
  val_interpolated =
    choice([
      double_quoted_value_interpolated,
      single_quoted_value_interpolated,
      unquoted_value_interpolated
    ])

  # Key-value pair parser: [export] KEY=VALUE[newline]
  #
  # Structure:
  # 1. Optionally ignore the "export" keyword
  # 2. Capture the variable name
  # 3. Ignore the equals sign
  # 4. Capture the value
  # 5. Ignore optional trailing newline
  # 6. Convert [key, value] to {key, value} tuple
  #
  # Examples:
  # - "KEY=value" -> {"KEY", "value"}
  # - "export FOO=bar" -> {"FOO", "bar"}
  # - "KEY=value # comment" -> {"KEY", "value"} (trimmed)
  key_value =
    optional(ignore(export))
    |> concat(var_name)
    |> ignore(equals)
    |> concat(val)
    |> ignore(optional(line_terminator))
    |> post_traverse(:to_tuple)

  # Key-value pair parser for interpolation mode
  # Value is a list of tokens instead of a string
  key_value_interpolated =
    optional(ignore(export))
    |> concat(var_name)
    |> ignore(equals)
    |> concat(val_interpolated)
    |> ignore(optional(line_terminator))
    |> post_traverse(:to_tuple_with_tokens)

  # Comment line parser: # comment text [newline]
  #
  # Comments are completely ignored and don't contribute to the parse result
  comment_line =
    comment
    |> ignore(optional(line_terminator))

  # Main parser entry point (non-interpolating mode)
  #
  # Returns: {:ok, [{key1, value1}, {key2, value2}, ...], remaining, context, position, offset}
  # Values are plain strings.
  defparsec :parse,
            ignore(times(ignored, min: 0))
            |> repeat(
              choice([key_value, ignore(comment_line)])
              |> ignore(times(ignored, min: 0))
            )

  # Parser entry point for interpolation mode
  #
  # Returns: {:ok, [{key1, tokens1}, {key2, tokens2}, ...], remaining, context, position, offset}
  # Tokens are lists of {:literal, str} and {:var, name} tuples.
  defparsec :parse_interpolated,
            ignore(times(ignored, min: 0))
            |> repeat(
              choice([key_value_interpolated, ignore(comment_line)])
              |> ignore(times(ignored, min: 0))
            )

  ## Helper Functions

  # Callback for repeat_while that stops when encountering a line terminator
  # Used by the comment parser to consume characters until end of line
  defp not_line_terminator(<<?\n, _::binary>>, context, _, _), do: {:halt, context}
  defp not_line_terminator(<<?\r, _::binary>>, context, _, _), do: {:halt, context}
  defp not_line_terminator(_, context, _, _), do: {:cont, context}

  # Trim whitespace from unquoted values (non-interpolating mode)
  defp trim_value(rest, [value], context, _line, _offset) when is_binary(value) do
    {rest, [String.trim(value)], context}
  end

  defp trim_value(rest, acc, context, _line, _offset) do
    {rest, acc, context}
  end

  # Build a list of tokens from parsed content (interpolating mode)
  # Tokens can be: {:literal, str}, {:var, name}, integers (char codes), or strings
  defp build_token_list(rest, acc, context, _line, _offset) do
    tokens = acc |> Enum.reverse() |> normalize_tokens([])
    {rest, [tokens], context}
  end

  # Wrap a string value as a single literal token (for single-quoted values in interpolating mode)
  defp wrap_as_literal_token(rest, [value], context, _line, _offset) when is_binary(value) do
    processed = value |> process_escapes([]) |> IO.iodata_to_binary()
    {rest, [[{:literal, processed}]], context}
  end

  defp wrap_as_literal_token(rest, acc, context, _line, _offset) do
    {rest, acc, context}
  end

  # Build a list of tokens from unquoted content, trimming trailing whitespace
  defp build_unquoted_token_list(rest, acc, context, _line, _offset) do
    tokens = acc |> Enum.reverse() |> normalize_tokens([]) |> trim_trailing_token()
    {rest, [tokens], context}
  end

  # Normalize accumulated content into a list of {:literal, str} and {:var, name} tokens
  # Combines adjacent characters and strings into single literals
  defp normalize_tokens([], acc), do: Enum.reverse(acc)

  # Variable reference (already tagged)
  defp normalize_tokens([{:var, name} | rest], acc) do
    normalize_tokens(rest, [{:var, name} | acc])
  end

  # Literal tuple (from escaped_dollar)
  defp normalize_tokens([{:literal, str} | rest], [{:literal, prev} | acc_rest]) do
    normalize_tokens(rest, [{:literal, prev <> str} | acc_rest])
  end

  defp normalize_tokens([{:literal, str} | rest], acc) do
    normalize_tokens(rest, [{:literal, str} | acc])
  end

  # String (from literal_dollar or reduce)
  defp normalize_tokens([str | rest], [{:literal, prev} | acc_rest]) when is_binary(str) do
    normalize_tokens(rest, [{:literal, prev <> str} | acc_rest])
  end

  defp normalize_tokens([str | rest], acc) when is_binary(str) do
    normalize_tokens(rest, [{:literal, str} | acc])
  end

  # Integer character code
  defp normalize_tokens([char | rest], [{:literal, prev} | acc_rest]) when is_integer(char) do
    normalize_tokens(rest, [{:literal, prev <> <<char::utf8>>} | acc_rest])
  end

  defp normalize_tokens([char | rest], acc) when is_integer(char) do
    normalize_tokens(rest, [{:literal, <<char::utf8>>} | acc])
  end

  # Process escape sequences in literal tokens
  defp normalize_tokens([other | rest], acc) do
    # Fallback for any unexpected token type
    normalize_tokens(rest, acc ++ [other])
  end

  # Trim trailing whitespace from the last literal token
  defp trim_trailing_token([]), do: []

  defp trim_trailing_token(tokens) do
    case List.last(tokens) do
      {:literal, str} ->
        trimmed = String.trim_trailing(str)

        if trimmed == "" do
          tokens |> Enum.reverse() |> tl() |> Enum.reverse() |> trim_trailing_token()
        else
          List.replace_at(tokens, -1, {:literal, trimmed})
        end

      _ ->
        tokens
    end
  end

  # Post-traversal callback to convert [value, key] list to {key, value} tuple
  #
  # This creates a proper structured representation of key-value pairs
  # instead of relying on a flat list that needs to be chunked later.
  #
  # Parameters:
  # - rest: Remaining input after parsing
  # - [value, key]: The parsed value and key from the accumulator
  #                 (Note: NimbleParsec builds accumulators in reverse order)
  # - context: Parser context
  # - _line, _offset: Position information (unused)
  #
  # Returns: {rest, [{key, value}], context}
  #
  # This makes the parser output self-documenting and type-safe.
  # The main Envious module can use Map.new/1 directly on the result.
  defp to_tuple(rest, [value, key], context, _line, _offset) do
    {rest, [{key, value}], context}
  end

  # Fallback clause for to_tuple when accumulator doesn't match expected pattern
  defp to_tuple(rest, acc, context, _line, _offset) do
    {rest, acc, context}
  end

  # Convert [tokens, key] to {key, tokens} tuple for interpolation mode
  # Tokens is a list of {:literal, str} and {:var, name} tuples
  defp to_tuple_with_tokens(rest, [tokens, key], context, _line, _offset) when is_list(tokens) do
    # Process escape sequences in literal tokens
    processed_tokens =
      Enum.map(tokens, fn
        {:literal, str} -> {:literal, str |> process_escapes([]) |> IO.iodata_to_binary()}
        other -> other
      end)

    {rest, [{key, processed_tokens}], context}
  end

  defp to_tuple_with_tokens(rest, acc, context, _line, _offset) do
    {rest, acc, context}
  end

  # Post-traversal callback to process escape sequences in quoted strings
  #
  # Converts escape sequences like \n, \t, \\, \", \' into their actual characters.
  #
  # Parameters:
  # - rest: Remaining input after parsing
  # - [value]: The parsed quoted string value
  # - context: Parser context
  # - _line, _offset: Position information (unused)
  #
  # Returns: {rest, [processed_value], context}
  #
  # Supported escape sequences:
  # - \n → newline (LF)
  # - \t → tab
  # - \r → carriage return (CR)
  # - \\ → backslash
  # - \" → double quote
  # - \' → single quote
  defp process_escape_sequences(rest, [value], context, _line, _offset) when is_binary(value) do
    # Process escape sequences using recursive pattern matching with iolists for efficiency
    processed = value |> process_escapes([]) |> IO.iodata_to_binary()
    {rest, [processed], context}
  end

  # Fallback clause for process_escape_sequences
  defp process_escape_sequences(rest, acc, context, _line, _offset) do
    {rest, acc, context}
  end

  # Recursively process escape sequences in a string
  # Uses iolists for efficient string building - accumulates fragments in reverse order
  # then converts to binary at the end

  # Base case: empty string, reverse accumulator and return
  defp process_escapes("", acc), do: Enum.reverse(acc)

  # IMPORTANT: Process \\ first to avoid matching it as part of other escape sequences
  defp process_escapes("\\\\" <> rest, acc), do: process_escapes(rest, ["\\" | acc])

  # Escape sequences
  defp process_escapes("\\n" <> rest, acc), do: process_escapes(rest, ["\n" | acc])
  defp process_escapes("\\t" <> rest, acc), do: process_escapes(rest, ["\t" | acc])
  defp process_escapes("\\r" <> rest, acc), do: process_escapes(rest, ["\r" | acc])
  defp process_escapes("\\\"" <> rest, acc), do: process_escapes(rest, ["\"" | acc])
  defp process_escapes("\\'" <> rest, acc), do: process_escapes(rest, ["'" | acc])

  # Any other character (including non-escape backslash sequences or regular chars)
  defp process_escapes(<<char::utf8, rest::binary>>, acc) do
    process_escapes(rest, [<<char::utf8>> | acc])
  end
end
