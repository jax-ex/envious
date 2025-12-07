defmodule Envious.ParserTest do
  use ExUnit.Case, async: true

  alias Envious.Parser

  test "simplest env" do
    assert Parser.parse("FOO=bar") == {:ok, [{"FOO", "bar"}], "", %{}, {1, 0}, 7}
  end

  test "multiple envs" do
    assert Parser.parse("FOO=bar\nBAZ=qux") ==
             {:ok, [{"FOO", "bar"}, {"BAZ", "qux"}], "", %{}, {2, 8}, 15}
  end

  test "underscore" do
    assert Parser.parse("FOO_BAR=bar\nBAZ_QUX=qux") ==
             {:ok, [{"FOO_BAR", "bar"}, {"BAZ_QUX", "qux"}], "", %{}, {2, 12}, 23}
  end

  test "lowercase env var name" do
    assert Parser.parse("foo_bar=bar") ==
             {:ok, [{"foo_bar", "bar"}], "", %{}, {1, 0}, 11}
  end

  test "export" do
    file = """
    export FOO=bar
    export BAZ=qux
    """

    assert Parser.parse(file) ==
             {:ok, [{"FOO", "bar"}, {"BAZ", "qux"}], "", %{}, {3, 30}, 30}
  end

  test "comments" do
    file = """
    # this is a comment
    export FOO=bar
    BAZ=qux # another comment
    """

    assert Parser.parse(file) ==
             {:ok, [{"FOO", "bar"}, {"BAZ", "qux"}], "", %{}, {4, 61}, 61}
  end

  test "variable interpolation with ${VAR} in double quotes" do
    file = """
    export A="foo"
    export B="bar and ${A}"
    """

    result = Envious.parse(file, interpolate: true)
    assert result == {:ok, %{"A" => "foo", "B" => "bar and foo"}}
  end

  test "variable interpolation with $VAR in double quotes" do
    file = """
    A=hello
    B="world and $A"
    """

    result = Envious.parse(file, interpolate: true)
    assert result == {:ok, %{"A" => "hello", "B" => "world and hello"}}
  end

  test "variable interpolation in unquoted values" do
    file = """
    export A=foo
    export B=bar-$A-baz
    """

    result = Envious.parse(file, interpolate: true)
    assert result == {:ok, %{"A" => "foo", "B" => "bar-foo-baz"}}
  end

  test "mixed variable interpolation formats" do
    file = """
    export A="A"
    export B="B and ${A} or $A"
    """

    result = Envious.parse(file, interpolate: true)
    assert result == {:ok, %{"A" => "A", "B" => "B and A or A"}}
  end

  test "variable interpolation with undefined variable resolves to empty with :empty option" do
    file = """
    B="value is $UNDEFINED"
    """

    result = Envious.parse(file, interpolate: true, undefined_vars: :empty)
    assert result == {:ok, %{"B" => "value is "}}
  end

  test "variable interpolation with undefined variable keeps literal with :keep option" do
    file = """
    B="value is $UNDEFINED"
    """

    result = Envious.parse(file, interpolate: true, undefined_vars: :keep)
    assert result == {:ok, %{"B" => "value is $UNDEFINED"}}
  end

  test "single quotes do not interpolate variables" do
    file = """
    A=foo
    B='$A is not interpolated'
    """

    result = Envious.parse(file, interpolate: true)
    assert result == {:ok, %{"A" => "foo", "B" => "$A is not interpolated"}}
  end

  test "multiple interpolations in one value" do
    file = """
    A=hello
    B=world
    C="$A $B from ${A} and ${B}"
    """

    result = Envious.parse(file, interpolate: true)

    assert result ==
             {:ok, %{"A" => "hello", "B" => "world", "C" => "hello world from hello and world"}}
  end

  test "chained variable interpolation" do
    file = """
    A=foo
    B=$A-bar
    C=$B-baz
    """

    result = Envious.parse(file, interpolate: true)
    assert result == {:ok, %{"A" => "foo", "B" => "foo-bar", "C" => "foo-bar-baz"}}
  end
end
