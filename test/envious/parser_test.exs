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

  test "underscore" do
    assert Parser.parse("FOO_BAR=bar\nBAZ_QUX=qux") ==
             {:ok, ["FOO_BAR", "bar", "BAZ_QUX", "qux"], "", %{}, {2, 12}, 23}
  end

  test "lowercase env var name" do
    assert Parser.parse("foo_bar=bar") ==
             {:ok, ["foo_bar", "bar"], "", %{}, {1, 0}, 11}
  end

  test "export" do
    file = """
    export FOO=bar
    export BAZ=qux
    """

    assert Parser.parse(file) ==
             {:ok, ["FOO", "bar", "BAZ", "qux"], "", %{}, {3, 30}, 30}
  end
end
