defmodule Envious do
  @moduledoc """
  Parser for .env files.

  Envious provides a simple, functional parser for .env files.
  It does not mutate the environment or have any side effects.

  ## Example

      iex> Envious.parse("KEY=value")
      {:ok, %{"KEY" => "value"}}

      iex> Envious.parse(\"\"\"
      ...> export FOO=bar
      ...> # This is a comment
      ...> BAZ=qux
      ...> \"\"\")
      {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}

  ## Using Envious

  You can `use Envious` to import both the parser functions and the environment
  variable helpers:

      use Envious

      # Now you have access to:
      parse!/1              # from Envious
      optional/1, optional/2  # from Envious.Env
      required!/1           # from Envious.Env
      integer!/1, float!/1, etc.  # from Envious.Env
  """

  defmacro __using__(_opts) do
    quote do
      import Envious
      import Envious.Env
    end
  end

  alias Envious.Parser

  @doc """
  Parse a .env file string into a map.

  Returns:
  - `{:ok, map}` on success, where map contains the parsed key-value pairs
  - `{:error, message}` on failure, with a descriptive error message including line/column info

  ## Examples

      iex> Envious.parse("PORT=3000")
      {:ok, %{"PORT" => "3000"}}

      iex> Envious.parse("export API_KEY=secret\\nDATABASE_URL=postgres://localhost")
      {:ok, %{"API_KEY" => "secret", "DATABASE_URL" => "postgres://localhost"}}

      iex> Envious.parse("KEY=\\"unclosed")
      {:error, "Parse error at line 1, column 5: could not parse remaining input"}
  """
  def parse(str) do
    case Parser.parse(str) do
      # Success with all input consumed
      {:ok, parsed, "", _context, _line, _offset} ->
        {:ok, Map.new(parsed)}

      # Success but with remaining unparsed input - this is an error
      {:ok, _parsed, remaining, _context, {line, col}, _offset} when remaining != "" ->
        preview = remaining |> String.slice(0, 20) |> String.trim()

        preview_text =
          if String.length(preview) < String.length(remaining), do: "#{preview}...", else: preview

        {:error,
         "Parse error at line #{line}, column #{col}: could not parse remaining input starting with: #{inspect(preview_text)}"}

      # Actual parse error from NimbleParsec (rare)
      {:error, message, _remaining, _context, {line, col}, _offset} ->
        {:error, "Parse error at line #{line}, column #{col}: #{message}"}
    end
  end

  @doc """
  Parse a .env file string into a map, raising on error.

  Same as `parse/1` but raises a `RuntimeError` if the input cannot be parsed.

  ## Examples

      iex> Envious.parse!("PORT=3000")
      %{"PORT" => "3000"}

      iex> Envious.parse!("export API_KEY=secret\\nDATABASE_URL=postgres://localhost")
      %{"API_KEY" => "secret", "DATABASE_URL" => "postgres://localhost"}

      iex> Envious.parse!("INVALID")
      ** (RuntimeError) Parse error at line 1, column 0: could not parse remaining input starting with: "INVALID"
  """
  def parse!(str) do
    case parse(str) do
      {:ok, map} -> map
      {:error, message} -> raise message
    end
  end
end
