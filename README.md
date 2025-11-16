# Envious

[![Hex.pm](https://img.shields.io/hexpm/v/envious.svg)](https://hex.pm/packages/envious)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/envious)

.env file parser for Elixir.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `envious` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:envious, "~> 1.0"}
  ]
end
```

Docs can be found at <https://hexdocs.pm/envious>.

## Usage

Envious is simply a file parser and is functional in nature. It does not
mutate the environment or have any side effects. It is up to the user to
decide how to use the parsed data.

```elixir
dotenv = """
# My .env file
export KEY1=value1
KEY2=value2 # export is optional
"""

Envious.parse(dotenv)
# => {:ok, %{"KEY1" => "value1", "KEY2" => "value2"}}
```

## API

- **`Envious.parse/1`** - Returns `{:ok, map}` or `{:error, message}`
- **`Envious.parse!/1`** - Returns `map` or raises `RuntimeError`

## Features

- **Comments**: Lines starting with `#` are ignored
- **Export prefix**: Optional `export` keyword (shell compatibility)
- **Quoted values**: Single and double quotes with escape sequences
- **Multi-line values**: Quoted values can span multiple lines
- **Empty values**: `KEY=` produces an empty string
- **Digits in keys**: Variable names like `DB2_HOST`, `API_V2_URL` are supported
- **Escape sequences**: `\n`, `\t`, `\r`, `\\`, `\"`, `\'` in quoted strings
- **Blank lines**: Multiple blank lines and trailing whitespace are handled correctly

```elixir
dotenv = """
# Database configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME="my database"

# API settings with escape sequences
MESSAGE="Line 1\\nLine 2"
PATH='C:\\\\Users\\\\path'
EMPTY=

# Multi-line certificate
CERT="-----BEGIN CERTIFICATE-----
MIIBkTCB+w...
-----END CERTIFICATE-----"
"""

Envious.parse(dotenv)
# => {:ok, %{
#      "DB_HOST" => "localhost",
#      "DB_PORT" => "5432",
#      "DB_NAME" => "my database",
#      "MESSAGE" => "Line 1\nLine 2",
#      "PATH" => "C:\\Users\\path",
#      "EMPTY" => "",
#      "CERT" => "-----BEGIN CERTIFICATE-----\nMIIBkTCB+w...\n-----END CERTIFICATE-----"
#    }}
```
### Example of how one might use this.

Now that `config/runtime.exs` exists in Elixir, it is possible to load environment
at application startup. Here are examples of how you might use Envious to load
`.env` files at application startup time.

#### Simple approach (fails fast on errors):

```elixir
# config/runtime.exs
import Config

# Load environment-specific .env file if it exists
env_file = ".#{config_env()}.env"

if File.exists?(env_file) do
  env_file |> File.read!() |> Envious.parse!() |> System.put_env()
end

config :my_app,
  key1: System.get_env("KEY1"),
  key2: System.get_env("KEY2")
```

#### Graceful approach (ignores missing or invalid files):

```elixir
# config/runtime.exs
import Config

# Try to load environment-specific .env file
# Silently continues if file doesn't exist or fails to parse
env_file = ".#{config_env()}.env"

with {:ok, contents} <- File.read(env_file),
     {:ok, env} <- Envious.parse(contents) do
  System.put_env(env)
end

config :my_app,
  key1: System.get_env("KEY1"),
  key2: System.get_env("KEY2")
```

#### Advanced approach (multiple files with priority):

This example loads multiple .env files in order, with later files overriding earlier ones,
but system environment variables always have the highest priority.

```elixir
# config/runtime.exs
import Config

# Load .env files in priority order (lowest to highest)
# - .env (defaults for all environments)
# - .env.local (local overrides, gitignored)
# - .env.{environment} (environment-specific)
env_files = [
  ".env",
  ".env.local",
  ".env.#{config_env()}"
]

# Accumulate environment variables from all files
loaded_env =
  Enum.reduce(env_files, %{}, fn file, acc ->
    with {:ok, contents} <- File.read(file),
         {:ok, env} <- Envious.parse(contents) do
      Map.merge(acc, env)
    else
      _ -> acc
    end
  end)

# Only set variables that aren't already in the system environment
# This gives system environment variables the highest priority
Enum.each(loaded_env, fn {key, value} ->
  if System.get_env(key) == nil do
    System.put_env(key, value)
  end
end)

config :my_app,
  database_url: System.fetch_env!("DATABASE_URL"),
  secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
```

## Which approach should I use?

- **Simple approach** - Use when .env files are required for your app to run. Crashes immediately if files are missing or invalid, making issues obvious during development.

- **Graceful approach** - Use for optional configuration files (development overrides, local settings). Silently continues if files don't exist or have errors.

- **Advanced approach** - Use when you need environment-specific files (`.env`, `.env.local`, `.env.production`) with cascading overrides, while respecting system environment variables.
