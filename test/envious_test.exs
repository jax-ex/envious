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

  # Variable name tests with digits
  test "variable name with digit at end" do
    assert Envious.parse("KEY1=value") == {:ok, %{"KEY1" => "value"}}
  end

  test "variable name with digit in middle" do
    assert Envious.parse("DB2_HOST=localhost") == {:ok, %{"DB2_HOST" => "localhost"}}
  end

  test "variable name with multiple digits" do
    assert Envious.parse("API_V2_URL=example.com") == {:ok, %{"API_V2_URL" => "example.com"}}
  end

  test "variable name with all digits after first char" do
    assert Envious.parse("KEY123=value") == {:ok, %{"KEY123" => "value"}}
  end

  test "variable name starting with digit fails" do
    assert {:error, message} = Envious.parse("1KEY=value")
    assert message =~ "line 1"
  end

  test "variable name as just digit fails" do
    assert {:error, message} = Envious.parse("1=value")
    assert message =~ "line 1"
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

  test "empty unquoted value" do
    assert Envious.parse("EMPTY=") ==
             {:ok, %{"EMPTY" => ""}}
  end

  test "empty unquoted value with newline" do
    assert Envious.parse("EMPTY=\nKEY=value") ==
             {:ok, %{"EMPTY" => "", "KEY" => "value"}}
  end

  # Escape sequence tests
  test "newline escape sequence in double quotes" do
    assert Envious.parse("MESSAGE=\"Line 1\\nLine 2\"") ==
             {:ok, %{"MESSAGE" => "Line 1\nLine 2"}}
  end

  test "tab escape sequence in double quotes" do
    assert Envious.parse("DATA=\"Column1\\tColumn2\"") ==
             {:ok, %{"DATA" => "Column1\tColumn2"}}
  end

  test "carriage return escape sequence" do
    assert Envious.parse("TEXT=\"Line1\\rLine2\"") ==
             {:ok, %{"TEXT" => "Line1\rLine2"}}
  end

  test "escaped backslash in double quotes" do
    assert Envious.parse("PATH=\"C:\\\\Users\\\\path\"") ==
             {:ok, %{"PATH" => "C:\\Users\\path"}}
  end

  test "escaped double quote in double quotes" do
    assert Envious.parse("QUOTE=\"She said \\\"hello\\\"\"") ==
             {:ok, %{"QUOTE" => "She said \"hello\""}}
  end

  test "escaped single quote in single quotes" do
    assert Envious.parse("QUOTE='It\\'s working'") ==
             {:ok, %{"QUOTE" => "It's working"}}
  end

  test "multiple escape sequences" do
    assert Envious.parse("DATA=\"Name:\\tJohn\\nAge:\\t30\"") ==
             {:ok, %{"DATA" => "Name:\tJohn\nAge:\t30"}}
  end

  # Multi-line value tests
  test "multi-line value with literal newline in double quotes" do
    file = """
    CERT="-----BEGIN CERTIFICATE-----
    MIIBkTCB+w
    -----END CERTIFICATE-----"
    """

    assert {:ok, result} = Envious.parse(file)
    assert result["CERT"] == "-----BEGIN CERTIFICATE-----\nMIIBkTCB+w\n-----END CERTIFICATE-----"
  end

  test "multi-line value with literal newline in single quotes" do
    file = """
    DATA='Line 1
    Line 2
    Line 3'
    """

    assert {:ok, result} = Envious.parse(file)
    assert result["DATA"] == "Line 1\nLine 2\nLine 3"
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

  # Whitespace edge cases
  test "leading whitespace in file" do
    assert Envious.parse("  \n\t\nKEY=value") == {:ok, %{"KEY" => "value"}}
  end

  test "trailing whitespace in file" do
    assert Envious.parse("KEY=value\n  \n\t") == {:ok, %{"KEY" => "value"}}
  end

  test "whitespace around equals sign fails" do
    # Whitespace around = is not allowed per shell syntax
    assert {:error, message} = Envious.parse("KEY = value")
    assert message =~ "line 1"
  end

  test "multiple blank lines between entries" do
    assert Envious.parse("FOO=bar\n\n\n\nBAZ=qux") == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end

  test "whitespace-only lines" do
    assert Envious.parse("FOO=bar\n   \t   \nBAZ=qux") == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end

  test "tabs in various positions" do
    assert Envious.parse("\t\tFOO=bar\t\t\nBAZ=qux") == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end

  # More error scenarios
  test "key without equals sign" do
    assert {:error, message} = Envious.parse("KEYONLY")
    assert message =~ "line 1"
  end

  test "multiple equals signs in value" do
    assert Envious.parse("KEY=a=b=c") == {:ok, %{"KEY" => "a=b=c"}}
  end

  test "base64-like value with equals" do
    assert Envious.parse("SECRET=abc123==") == {:ok, %{"SECRET" => "abc123=="}}
  end

  test "just an equals sign" do
    assert {:error, message} = Envious.parse("=")
    assert message =~ "line 1"
  end

  test "export keyword without key" do
    assert {:error, message} = Envious.parse("export ")
    assert message =~ "could not parse"
  end

  test "export keyword without value" do
    assert {:error, message} = Envious.parse("export KEY")
    assert message =~ "could not parse"
  end

  # Comment edge cases
  test "empty comment" do
    assert Envious.parse("#\nKEY=value") == {:ok, %{"KEY" => "value"}}
  end

  test "comment as first line" do
    assert Envious.parse("# First line comment\nKEY=value") == {:ok, %{"KEY" => "value"}}
  end

  test "multiple consecutive comment lines" do
    file = """
    # Comment 1
    # Comment 2
    # Comment 3
    KEY=value
    """

    assert Envious.parse(file) == {:ok, %{"KEY" => "value"}}
  end

  test "hash in quoted value is not a comment" do
    assert Envious.parse("KEY=\"value#notcomment\"") == {:ok, %{"KEY" => "value#notcomment"}}
  end

  test "hash in single-quoted value is not a comment" do
    assert Envious.parse("KEY='value#notcomment'") == {:ok, %{"KEY" => "value#notcomment"}}
  end

  test "comment with special characters" do
    assert Envious.parse("# Comment with @#$%^&*()\nKEY=value") == {:ok, %{"KEY" => "value"}}
  end

  # Line ending variations
  test "windows line endings" do
    assert Envious.parse("FOO=bar\r\nBAZ=qux\r\n") == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end

  test "mixed unix and windows line endings" do
    assert Envious.parse("FOO=bar\nBAZ=qux\r\nQUX=foo") ==
             {:ok, %{"FOO" => "bar", "BAZ" => "qux", "QUX" => "foo"}}
  end

  test "no trailing newline on last line" do
    assert Envious.parse("FOO=bar\nBAZ=qux") == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end

  test "carriage return only" do
    assert Envious.parse("FOO=bar\rBAZ=qux") == {:ok, %{"FOO" => "bar", "BAZ" => "qux"}}
  end

  # Complex scenarios
  test "mix of exports, comments, quoted and unquoted values" do
    file = """
    # Database configuration
    export DB_HOST=localhost
    DB_PORT=5432
    DB_NAME="my database"

    # API settings
    API_KEY='secret-key-123'
    API_URL=https://api.example.com
    """

    assert Envious.parse(file) ==
             {:ok,
              %{
                "DB_HOST" => "localhost",
                "DB_PORT" => "5432",
                "DB_NAME" => "my database",
                "API_KEY" => "secret-key-123",
                "API_URL" => "https://api.example.com"
              }}
  end

  test "unicode BOM at start of file" do
    # UTF-8 BOM is U+FEFF
    assert Envious.parse("\uFEFFKEY=value") == {:ok, %{"KEY" => "value"}}
  end

  test "multiple equals in quoted value" do
    assert Envious.parse("MATH=\"2+2=4 and 3+3=6\"") == {:ok, %{"MATH" => "2+2=4 and 3+3=6"}}
  end

  test "extremely long value" do
    long_value = String.duplicate("a", 10000)
    assert Envious.parse("KEY=#{long_value}") == {:ok, %{"KEY" => long_value}}
  end

  test "many key-value pairs" do
    pairs =
      Enum.map(1..100, fn i -> "KEY#{i}=value#{i}" end)
      |> Enum.join("\n")

    expected =
      Enum.map(1..100, fn i -> {"KEY#{i}", "value#{i}"} end)
      |> Map.new()

    assert Envious.parse(pairs) == {:ok, expected}
  end
end
