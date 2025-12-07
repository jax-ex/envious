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

  ## Variable Interpolation

  Enable shell-style variable interpolation with the `:interpolate` option:

      iex> Envious.parse("BASE=/app\\nPATH=$BASE/bin", interpolate: true)
      {:ok, %{"BASE" => "/app", "PATH" => "/app/bin"}}

  See `parse/2` for all available options.

  ## Using Envious

  You can `use Envious` to import both the parser functions and the environment
  variable helpers:

      use Envious

      # Now you have access to:
      parse!/1, parse!/2        # from Envious
      optional/1, optional/2    # from Envious.Env
      required!/1               # from Envious.Env
      integer!/1, float!/1, etc.  # from Envious.Env
  """

  defmacro __using__(_opts) do
    quote do
      import Envious
      import Envious.Env
    end
  end

  alias Envious.Parser

  @type interpolation_opt :: {:interpolate, boolean()}
  @type undefined_vars_opt :: {:undefined_vars, :keep | :empty | :error}
  @type parse_opt :: interpolation_opt() | undefined_vars_opt()

  @doc """
  Parse a .env file string into a map.

  ## Options

  - `:interpolate` - Enable variable interpolation with `$VAR` or `${VAR}` syntax.
    Defaults to `false`.
  - `:undefined_vars` - How to handle undefined variables when interpolation is enabled:
    - `:keep` - Keep the literal `$VAR` text (default, safest)
    - `:empty` - Replace with empty string (shell-compatible)
    - `:error` - Return an error for undefined variables

  ## Examples

      iex> Envious.parse("PORT=3000")
      {:ok, %{"PORT" => "3000"}}

      iex> Envious.parse("export API_KEY=secret\\nDATABASE_URL=postgres://localhost")
      {:ok, %{"API_KEY" => "secret", "DATABASE_URL" => "postgres://localhost"}}

      # Interpolation disabled by default
      iex> Envious.parse("A=foo\\nB=$A")
      {:ok, %{"A" => "foo", "B" => "$A"}}

      # Enable interpolation
      iex> Envious.parse("A=foo\\nB=$A", interpolate: true)
      {:ok, %{"A" => "foo", "B" => "foo"}}

      # Undefined variables with :keep (default)
      iex> Envious.parse("B=$UNDEFINED", interpolate: true)
      {:ok, %{"B" => "$UNDEFINED"}}

      # Undefined variables with :empty
      iex> Envious.parse("B=$UNDEFINED", interpolate: true, undefined_vars: :empty)
      {:ok, %{"B" => ""}}

      iex> Envious.parse("KEY=\\"unclosed")
      {:error, "Parse error at line 1, column 5: could not parse remaining input"}
  """
  @spec parse(String.t(), [parse_opt()]) :: {:ok, map()} | {:error, String.t()}
  def parse(str, opts \\ []) do
    interpolate? = Keyword.get(opts, :interpolate, false)
    undefined_vars = Keyword.get(opts, :undefined_vars, :keep)

    parser_result =
      if interpolate? do
        Parser.parse_interpolated(str)
      else
        Parser.parse(str)
      end

    case parser_result do
      # Success with all input consumed
      {:ok, parsed, "", _context, _line, _offset} ->
        if interpolate? do
          resolve_interpolations(parsed, undefined_vars)
        else
          {:ok, Map.new(parsed)}
        end

      # Success but with remaining unparsed input - this is an error
      {:ok, _parsed, remaining, _context, {line, col}, _offset} when remaining != "" ->
        preview = remaining |> String.slice(0, 20) |> String.trim()

        preview_text =
          if String.length(preview) < String.length(remaining), do: "#{preview}...", else: preview

        {:error,
         "Parse error at line #{line}, column #{col}: could not parse remaining input starting with: #{inspect(preview_text)}"}
    end
  end

  # Resolve variable interpolations in parsed key-value pairs
  # Processes in order so earlier variables are available to later ones
  defp resolve_interpolations(parsed, undefined_vars) do
    Enum.reduce_while(parsed, {:ok, %{}}, fn {key, tokens}, {:ok, acc} ->
      case resolve_tokens(tokens, acc, undefined_vars) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  # Resolve a list of tokens to a string value
  defp resolve_tokens(tokens, env, undefined_vars) when is_list(tokens) do
    result =
      Enum.reduce_while(tokens, [], fn token, acc ->
        case resolve_token(token, env, undefined_vars) do
          {:ok, str} -> {:cont, [str | acc]}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      parts -> {:ok, parts |> Enum.reverse() |> IO.iodata_to_binary()}
    end
  end

  # Handle empty token list
  defp resolve_tokens([], _env, _undefined_vars), do: {:ok, ""}

  # Resolve a single token
  defp resolve_token({:literal, str}, _env, _undefined_vars), do: {:ok, str}

  defp resolve_token({:var, name}, env, undefined_vars) do
    case Map.fetch(env, name) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        case undefined_vars do
          :keep -> {:ok, "$" <> name}
          :empty -> {:ok, ""}
          :error -> {:error, "Undefined variable: #{name}"}
        end
    end
  end

  @doc """
  Parse a .env file string into a map, raising on error.

  Same as `parse/2` but raises a `RuntimeError` if the input cannot be parsed
  or if an undefined variable error occurs.

  ## Examples

      iex> Envious.parse!("PORT=3000")
      %{"PORT" => "3000"}

      iex> Envious.parse!("export API_KEY=secret\\nDATABASE_URL=postgres://localhost")
      %{"API_KEY" => "secret", "DATABASE_URL" => "postgres://localhost"}

      iex> Envious.parse!("A=foo\\nB=$A", interpolate: true)
      %{"A" => "foo", "B" => "foo"}

      iex> Envious.parse!("INVALID")
      ** (RuntimeError) Parse error at line 1, column 0: could not parse remaining input starting with: "INVALID"
  """
  @spec parse!(String.t(), [parse_opt()]) :: map()
  def parse!(str, opts \\ []) do
    case parse(str, opts) do
      {:ok, map} -> map
      {:error, message} -> raise message
    end
  end
end
