# Envious

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
at application startup. This is a simple example of how one might use Envious to load
`.env` files at application startup time.

```elixir
# config/runtime.exs
with {:ok, file} <- File.read(".env"),
     {:ok, env} <- Envious.parse(file) do
  System.put_env(env)
end

config :my_app,
  key1: System.get_env("KEY1"),
  key2: System.get_env("KEY2")
```
