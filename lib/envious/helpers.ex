defmodule Envious.Helpers do
  @moduledoc """
  Helper functions for working with environment variables in configuration files.

  This module provides convenient functions for extracting and converting environment
  variables from `System.get_env/1`. These helpers are designed to work seamlessly
  with Envious for loading `.env` files into the system environment.

  ## Typical Workflow

      # Load .env file into system environment
      ".env" |> File.read!() |> Envious.parse!() |> System.put_env()

      # Use helpers in config/runtime.exs
      import Envious.Helpers

      config :my_app, MyApp.Repo,
        url: required!("DATABASE_URL"),
        pool_size: optional("POOL_SIZE", "10") |> integer!()

      config :my_app,
        port: required!("PORT") |> integer!(),
        host: optional("HOST", "localhost"),
        enabled: optional("ENABLED", "true") |> boolean!(),
        log_level: optional("LOG_LEVEL", "info") |> atom!(),
        allowed_origins: optional("ALLOWED_ORIGINS", "http://localhost") |> list!(),
        timeout: optional("TIMEOUT", "30s") |> interval!(:milliseconds)

  ## Value Extraction

  The module provides three functions for extracting environment variable values:

  - `optional/1` - Returns the value or `nil` if not set
  - `optional/2` - Returns the value or a default if not set
  - `required!/1` - Returns the value or raises `System.EnvError` if not set

  Note that empty strings (`""`) are considered valid values and will not trigger
  defaults or raise errors.

  ## Type Conversions

  All type conversion functions follow the bang (`!`) convention and will raise
  an `ArgumentError` if the value cannot be converted. This fail-fast approach
  is appropriate for configuration that should be validated at application startup.

  ## Error Handling

  The module raises two types of errors:

  - `System.EnvError` - Raised by `required!/1` when an environment variable is missing
  - `ArgumentError` - Raised by type converters when a value cannot be converted

  Available converters:
  - `integer!/1` - Convert to integer
  - `float!/1` - Convert to float
  - `boolean!/1` - Convert to boolean (handles "true", "false", "1", "0", "yes", "no", "on", "off")
  - `atom!/1` - Convert to existing atom (safe, won't create new atoms)
  - `list!/1` - Split string into list (comma-separated by default)
  - `list!/2` - Split string and transform each element
  - `interval!/2` - Parse time interval strings like "30s", "5m", "2h"
  - `uri!/1` - Parse URI string into URI struct

  ## Examples

      # Required value (raises if missing)
      required!("DATABASE_URL")
      #=> "postgresql://localhost/mydb"

      # Optional with default
      optional("PORT", "4000")
      #=> "4000"

      # Optional without default (returns nil if missing)
      optional("OPTIONAL_FEATURE")
      #=> nil

      # Type conversions
      optional("PORT", "4000") |> integer!()
      #=> 4000

      optional("ENABLED", "true") |> boolean!()
      #=> true

      optional("LOG_LEVEL", "info") |> atom!()
      #=> :info

      optional("CORS_ORIGINS", "http://localhost,https://example.com") |> list!()
      #=> ["http://localhost", "https://example.com"]

      # Custom list transformation
      optional("PORTS", "4000,4001,4002") |> list!(&integer!/1)
      #=> [4000, 4001, 4002]

      # Time intervals (defaults to milliseconds like :timer)
      optional("TIMEOUT", "30s") |> interval!()
      #=> 30000

      optional("CACHE_TTL", "5m") |> interval!(:seconds)
      #=> 300
  """

  @doc """
  Gets an environment variable value, returning `nil` if not set.

  This is useful when you want to distinguish between an unset variable and
  an empty string, or when `nil` is an acceptable value in your configuration.

  ## Examples

      # Variable is set
      System.put_env("MY_VAR", "value")
      optional("MY_VAR")
      #=> "value"

      # Variable is not set
      System.delete_env("MY_VAR")
      optional("MY_VAR")
      #=> nil

      # Variable is set to empty string
      System.put_env("MY_VAR", "")
      optional("MY_VAR")
      #=> ""
  """
  @spec optional(String.t()) :: String.t() | nil
  def optional(key) when is_binary(key) do
    System.get_env(key)
  end

  @doc """
  Gets an environment variable value, returning a default if not set.

  Note that empty strings are considered valid values and will not trigger
  the default. Only `nil` (variable not set) will cause the default to be used.

  ## Examples

      # Variable is set
      System.put_env("MY_VAR", "value")
      optional("MY_VAR", "default")
      #=> "value"

      # Variable is not set
      System.delete_env("MY_VAR")
      optional("MY_VAR", "default")
      #=> "default"

      # Variable is set to empty string
      System.put_env("MY_VAR", "")
      optional("MY_VAR", "default")
      #=> ""
  """
  @spec optional(String.t(), String.t()) :: String.t()
  def optional(key, default) when is_binary(key) and is_binary(default) do
    System.get_env(key, default)
  end

  @doc """
  Gets an environment variable value, raising if not set.

  Raises a `System.EnvError` if the environment variable is not set or is `nil`.

  ## Examples

      # Variable is set
      System.put_env("MY_VAR", "value")
      required!("MY_VAR")
      #=> "value"

      # Variable is not set
      System.delete_env("MY_VAR")
      required!("MY_VAR")
      #=> ** (System.EnvError) could not fetch environment variable "MY_VAR" because it is not set
  """
  @spec required!(String.t()) :: String.t()
  def required!(key) when is_binary(key) do
    System.fetch_env!(key)
  end

  @doc """
  Converts a string value to an integer.

  Raises an `ArgumentError` if the value cannot be parsed as an integer.

  ## Examples

      integer!("42")
      #=> 42

      integer!("-100")
      #=> -100

      integer!("not a number")
      #=> ** (ArgumentError) could not convert "not a number" to integer
  """
  @spec integer!(String.t() | nil) :: integer()
  def integer!(nil) do
    raise ArgumentError, "cannot convert nil to integer"
  end

  def integer!(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        int

      _ ->
        raise ArgumentError, ~s(could not convert "#{value}" to integer)
    end
  end

  @doc """
  Converts a string value to a float.

  Raises an `ArgumentError` if the value cannot be parsed as a float.

  ## Examples

      float!("3.14")
      #=> 3.14

      float!("-2.5")
      #=> -2.5

      float!("42")
      #=> 42.0

      float!("not a number")
      #=> ** (ArgumentError) could not convert "not a number" to float
  """
  @spec float!(String.t() | nil) :: float()
  def float!(nil) do
    raise ArgumentError, "cannot convert nil to float"
  end

  def float!(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} ->
        float

      _ ->
        raise ArgumentError, ~s(could not convert "#{value}" to float)
    end
  end

  @doc """
  Converts a string value to a boolean.

  Recognizes common boolean representations (case-insensitive):
  - `true`: "true", "1", "yes", "on"
  - `false`: "false", "0", "no", "off"

  Raises an `ArgumentError` if the value is not a recognized boolean string.

  ## Examples

      boolean!("true")
      #=> true

      boolean!("FALSE")
      #=> false

      boolean!("1")
      #=> true

      boolean!("0")
      #=> false

      boolean!("yes")
      #=> true

      boolean!("no")
      #=> false

      boolean!("on")
      #=> true

      boolean!("off")
      #=> false

      boolean!("maybe")
      #=> ** (ArgumentError) could not convert "maybe" to boolean
  """
  @spec boolean!(String.t() | nil) :: boolean()
  def boolean!(nil) do
    raise ArgumentError, "cannot convert nil to boolean"
  end

  def boolean!(value) when is_binary(value) do
    case String.downcase(value) do
      v when v in ["true", "1", "yes", "on"] -> true
      v when v in ["false", "0", "no", "off"] -> false
      _ -> raise ArgumentError, ~s(could not convert "#{value}" to boolean)
    end
  end

  @doc """
  Converts a string value to an existing atom.

  This function uses `String.to_existing_atom/1` to safely convert strings
  to atoms without creating new atoms dynamically, which prevents potential
  memory leaks.

  Raises an `ArgumentError` if the atom does not already exist.

  ## Examples

      # Atom exists
      :info
      atom!("info")
      #=> :info

      # Atom doesn't exist
      atom!("nonexistent_atom_12345")
      #=> ** (ArgumentError) atom "nonexistent_atom_12345" does not exist
  """
  @spec atom!(String.t() | nil) :: atom()
  def atom!(nil) do
    raise ArgumentError, "cannot convert nil to atom"
  end

  def atom!(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError ->
      raise ArgumentError, ~s(atom "#{value}" does not exist)
  end

  @doc """
  Splits a string into a list using a delimiter.

  Accepts options:
  - `:delimiter` - The string to split on (default: `","`)
  - `:trim` - Whether to trim whitespace from each element (default: `true`)

  Can also accept a transformer function as the second argument to transform
  each element after splitting. When using a transformer, options can be passed
  as the third argument.

  ## Examples

      list!("a,b,c")
      #=> ["a", "b", "c"]

      list!("foo, bar, baz")
      #=> ["foo", "bar", "baz"]

      list!("x:y:z", delimiter: ":")
      #=> ["x", "y", "z"]

      list!(" a , b , c ", trim: false)
      #=> [" a ", " b ", " c "]

      list!("")
      #=> [""]

      # With transformer function
      list!("1,2,3", &integer!/1)
      #=> [1, 2, 3]

      list!("true,false,true", &boolean!/1)
      #=> [true, false, true]

      # With transformer and options
      list!("1:2:3", &integer!/1, delimiter: ":")
      #=> [1, 2, 3]
  """
  @spec list!(String.t() | nil) :: [String.t()]
  @spec list!(String.t() | nil, keyword() | (String.t() -> any())) :: [String.t()] | [any()]
  @spec list!(String.t() | nil, (String.t() -> any()), keyword()) :: [any()]

  def list!(nil) do
    raise ArgumentError, "cannot convert nil to list"
  end

  def list!(value) when is_binary(value) do
    list!(value, [])
  end

  def list!(nil, _opts_or_transformer) do
    raise ArgumentError, "cannot convert nil to list"
  end

  def list!(value, opts) when is_binary(value) and is_list(opts) do
    delimiter = Keyword.get(opts, :delimiter, ",")
    trim = Keyword.get(opts, :trim, true)

    parts = String.split(value, delimiter)

    if trim do
      Enum.map(parts, &String.trim/1)
    else
      parts
    end
  end

  def list!(value, transformer) when is_binary(value) and is_function(transformer, 1) do
    list!(value, transformer, [])
  end

  def list!(nil, _transformer, _opts) do
    raise ArgumentError, "cannot convert nil to list"
  end

  def list!(value, transformer, opts)
      when is_binary(value) and is_function(transformer, 1) and is_list(opts) do
    value
    |> list!(opts)
    |> Enum.map(transformer)
  end

  @doc """
  Parses a time interval string and converts it to the specified unit.

  Defaults to `:milliseconds` to match Erlang's `:timer` module convention.

  Supported input formats:
  - `"300"` - plain number (treated as milliseconds)
  - `"30s"` - seconds
  - `"5m"` - minutes
  - `"2h"` - hours
  - `"1d"` - days
  - `"500ms"` - milliseconds

  Supported output units:
  - `:milliseconds` (default)
  - `:seconds`
  - `:minutes`
  - `:hours`
  - `:days`

  ## Examples

      # Plain numbers default to milliseconds (like :timer.sleep/1)
      interval!("300")
      #=> 300

      interval!("30s")
      #=> 30000

      interval!("5m")
      #=> 300000

      # Custom units
      interval!("5m", :seconds)
      #=> 300

      interval!("2h", :minutes)
      #=> 120

      interval!("1d", :hours)
      #=> 24

      interval!("invalid")
      #=> ** (ArgumentError) could not parse interval "invalid"
  """
  @spec interval!(String.t() | nil) :: integer()
  @spec interval!(String.t() | nil, atom()) :: integer()
  def interval!(nil) do
    raise ArgumentError, "cannot convert nil to interval"
  end

  def interval!(value) when is_binary(value) do
    interval!(value, :milliseconds)
  end

  def interval!(nil, _unit) do
    raise ArgumentError, "cannot convert nil to interval"
  end

  def interval!(value, unit) when is_binary(value) and is_atom(unit) do
    case parse_interval(value) do
      {:ok, milliseconds} ->
        convert_interval(milliseconds, unit)

      :error ->
        raise ArgumentError, ~s(could not parse interval "#{value}")
    end
  end

  # Parse interval string to milliseconds
  defp parse_interval(value) do
    cond do
      # With unit suffix: "30s", "5m", "2h", etc.
      match = Regex.run(~r/^(\d+(?:\.\d+)?)(ms|s|m|h|d)$/, value) ->
        [_, number, unit] = match

        case Float.parse(number) do
          {num, ""} -> {:ok, convert_to_milliseconds(num, unit)}
          _ -> :error
        end

      # Plain number (no unit): treat as milliseconds
      Regex.match?(~r/^\d+(?:\.\d+)?$/, value) ->
        case Float.parse(value) do
          {num, ""} -> {:ok, trunc(num)}
          _ -> :error
        end

      true ->
        :error
    end
  end

  defp convert_to_milliseconds(num, "ms"), do: trunc(num)
  defp convert_to_milliseconds(num, "s"), do: trunc(num * 1000)
  defp convert_to_milliseconds(num, "m"), do: trunc(num * 60 * 1000)
  defp convert_to_milliseconds(num, "h"), do: trunc(num * 60 * 60 * 1000)
  defp convert_to_milliseconds(num, "d"), do: trunc(num * 24 * 60 * 60 * 1000)

  defp convert_interval(milliseconds, :milliseconds), do: milliseconds
  defp convert_interval(milliseconds, :seconds), do: div(milliseconds, 1000)
  defp convert_interval(milliseconds, :minutes), do: div(milliseconds, 60 * 1000)
  defp convert_interval(milliseconds, :hours), do: div(milliseconds, 60 * 60 * 1000)
  defp convert_interval(milliseconds, :days), do: div(milliseconds, 24 * 60 * 60 * 1000)

  defp convert_interval(_milliseconds, unit) do
    raise ArgumentError, ~s(unsupported interval unit: #{inspect(unit)})
  end

  @doc """
  Parses a URI string into a `URI` struct.

  Raises an `ArgumentError` if the URI cannot be parsed.

  ## Examples

      uri!("https://example.com:8080/path?query=value")
      #=> %URI{
      #=>   scheme: "https",
      #=>   host: "example.com",
      #=>   port: 8080,
      #=>   path: "/path",
      #=>   query: "query=value"
      #=> }

      uri!("postgresql://localhost/mydb")
      #=> %URI{scheme: "postgresql", host: "localhost", path: "/mydb", ...}
  """
  @spec uri!(String.t() | nil) :: URI.t()
  def uri!(nil) do
    raise ArgumentError, "cannot convert nil to URI"
  end

  def uri!(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, uri} ->
        uri

      {:error, _} ->
        raise ArgumentError, ~s(could not parse URI "#{value}")
    end
  end
end
