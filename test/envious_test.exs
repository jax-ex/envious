defmodule EnviousTest do
  use ExUnit.Case, async: true

  test "simple parse" do
    assert Envious.parse("FOO=bar") == {:ok, %{"FOO" => "bar"}}
  end

  test "mulitline parse" do
    assert Envious.parse("FOO=bar\nBAZ=qux") == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end

  test "export parse" do
    file = """
    export FOO=bar
    export BAZ=qux
    """

    assert Envious.parse(file) == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end
end
