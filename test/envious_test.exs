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

  test "ingore comments" do
    file = """
    # this is a comment
    export FOO=bar
    BAZ=qux # another comment
    """

    assert Envious.parse(file) == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end

  test "numeric value" do
    assert Envious.parse("PORT=3000") == {:ok, %{"PORT" => "3000"}}
  end

  test "uppercase letters in value" do
    assert Envious.parse("API_KEY=ABC123") == {:ok, %{"API_KEY" => "ABC123"}}
  end

  test "mixed alphanumeric value" do
    assert Envious.parse("TOKEN=abc123XYZ") == {:ok, %{"TOKEN" => "abc123XYZ"}}
  end

  test "database URL" do
    assert Envious.parse("DATABASE_URL=postgres://localhost:5432/mydb") ==
             {:ok, %{"DATABASE_URL" => "postgres://localhost:5432/mydb"}}
  end

  test "file path" do
    assert Envious.parse("PATH=/usr/local/bin:/usr/bin") ==
             {:ok, %{"PATH" => "/usr/local/bin:/usr/bin"}}
  end

  test "URL with query params" do
    assert Envious.parse("API_URL=https://api.example.com/v1?key=value&foo=bar") ==
             {:ok, %{"API_URL" => "https://api.example.com/v1?key=value&foo=bar"}}
  end

  test "value with dots, dashes, underscores" do
    assert Envious.parse("VERSION=1.2.3-beta_1") ==
             {:ok, %{"VERSION" => "1.2.3-beta_1"}}
  end

  test "double-quoted value with spaces" do
    assert Envious.parse("MESSAGE=\"Hello World\"") ==
             {:ok, %{"MESSAGE" => "Hello World"}}
  end

  test "single-quoted value with spaces" do
    assert Envious.parse("MESSAGE='Hello World'") ==
             {:ok, %{"MESSAGE" => "Hello World"}}
  end

  test "double-quoted value with special chars" do
    assert Envious.parse("PATH=\"/usr/local/bin:/usr/bin\"") ==
             {:ok, %{"PATH" => "/usr/local/bin:/usr/bin"}}
  end

  test "single-quoted value with special chars" do
    assert Envious.parse("PATH='/usr/local/bin:/usr/bin'") ==
             {:ok, %{"PATH" => "/usr/local/bin:/usr/bin"}}
  end

  test "empty double-quoted value" do
    assert Envious.parse("EMPTY=\"\"") ==
             {:ok, %{"EMPTY" => ""}}
  end

  test "empty single-quoted value" do
    assert Envious.parse("EMPTY=''") ==
             {:ok, %{"EMPTY" => ""}}
  end

  # Error handling tests
  test "unclosed double quote returns error" do
    assert {:error, message} = Envious.parse("KEY=\"unclosed")
    assert message =~ "line 1"
    assert message =~ "could not parse"
  end

  test "unclosed single quote returns error" do
    assert {:error, message} = Envious.parse("KEY='unclosed")
    assert message =~ "line 1"
    assert message =~ "could not parse"
  end

  test "invalid syntax returns error" do
    assert {:error, message} = Envious.parse("INVALID WITHOUT EQUALS")
    assert message =~ "line 1"
  end

  test "partial valid with trailing invalid returns error" do
    assert {:error, message} = Envious.parse("KEY=value\nINVALID")
    assert message =~ "line 2"
  end

  test "empty string parses successfully" do
    assert Envious.parse("") == {:ok, %{}}
  end

  test "only comments parses successfully" do
    assert Envious.parse("# comment\n# another") == {:ok, %{}}
  end
end
