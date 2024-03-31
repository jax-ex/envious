# Envious

.env file parser for Elixir.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `envious` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:envious, "~> 0.1.0"}
  ]
end
```

Docs can be found at <https://hexdocs.pm/envious>.

## Usage

Envious is simply a file parser and is functional in nature. It does not
mutate the environment or have any side effects. It is up to the user to
decide how to use the parsed data.

```elixir
Envious.parse(".env")
# => {:ok, %{"KEY1" => "value1", "KEY2" => "value2"}}
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
