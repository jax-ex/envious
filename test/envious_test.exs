defmodule EnviousTest do
  use ExUnit.Case

  test "greets the world" do
    assert Envious.parse("FOO=bar") == {:ok, %{"FOO" => "bar"}}
  end
end
