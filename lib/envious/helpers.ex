defmodule Envious.Helpers do
  @moduledoc """
  Deprecated: Use `Envious.Env` instead.

  This module exists for backward compatibility and will be removed in 2.0.

  All functions delegate to `Envious.Env`.
  """

  defdelegate optional(key), to: Envious.Env
  defdelegate optional(key, default), to: Envious.Env
  defdelegate required!(key), to: Envious.Env
  defdelegate integer!(value), to: Envious.Env
  defdelegate float!(value), to: Envious.Env
  defdelegate boolean!(value), to: Envious.Env
  defdelegate atom!(value), to: Envious.Env
  defdelegate list!(value), to: Envious.Env
  defdelegate list!(value, opts_or_transformer), to: Envious.Env
  defdelegate list!(value, transformer, opts), to: Envious.Env
  defdelegate interval!(value), to: Envious.Env
  defdelegate interval!(value, unit), to: Envious.Env
  defdelegate uri!(value), to: Envious.Env
  defdelegate ip!(value), to: Envious.Env
end
