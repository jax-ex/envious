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
  """

  alias Envious.Parser

  @doc """
  Parse a .env file string into a map.

  Returns `{:ok, map}` where map contains the parsed key-value pairs.

  The parser returns the raw NimbleParsec result tuple on error,
  which can be pattern matched for debugging.

  ## Examples

      iex> Envious.parse("PORT=3000")
      {:ok, %{"PORT" => "3000"}}

      iex> Envious.parse("export API_KEY=secret\\nDATABASE_URL=postgres://localhost")
      {:ok, %{"API_KEY" => "secret", "DATABASE_URL" => "postgres://localhost"}}
  """
  def parse(str) do
    with {:ok, parsed, _remaining, _context, _line, _offset} <- Parser.parse(str) do
      # Parser returns a list of {key, value} tuples, which Map.new/1 handles directly
      {:ok, Map.new(parsed)}
    end
  end
end
