defmodule Envious.ParserTest do
  use ExUnit.Case, async: true

  alias Envious.Parser

  test "simplest env" do
    assert Parser.parse("FOO=bar") == {:ok, ["FOO", "bar"], "", %{}, {1, 0}, 7}
  end

  test "multiple envs" do
    assert Parser.parse("FOO=bar\nBAZ=qux") ==
             {:ok, ["FOO", "bar", "BAZ", "qux"], "", %{}, {2, 8}, 15}
  end
end
