defmodule Envious.HelpersTest do
  use ExUnit.Case, async: true
  import Envious.Helpers

  describe "optional/1" do
    setup do
      System.delete_env("TEST_VAR")
      :ok
    end

    test "returns value when environment variable is set" do
      System.put_env("TEST_VAR", "value")
      assert optional("TEST_VAR") == "value"
    end

    test "returns nil when environment variable is not set" do
      assert optional("TEST_VAR") == nil
    end

    test "returns empty string when variable is set to empty string" do
      System.put_env("TEST_VAR", "")
      assert optional("TEST_VAR") == ""
    end
  end

  describe "optional/2" do
    setup do
      System.delete_env("TEST_VAR")
      :ok
    end

    test "returns value when environment variable is set" do
      System.put_env("TEST_VAR", "actual")
      assert optional("TEST_VAR", "default") == "actual"
    end

    test "returns default when environment variable is not set" do
      assert optional("TEST_VAR", "default") == "default"
    end

    test "returns empty string when variable is set to empty string, not default" do
      System.put_env("TEST_VAR", "")
      assert optional("TEST_VAR", "default") == ""
    end

    test "works with numeric defaults as strings" do
      assert optional("TEST_VAR", "42") == "42"
    end
  end

  describe "required!/1" do
    setup do
      System.delete_env("TEST_REQUIRED")
      :ok
    end

    test "returns value when environment variable is set" do
      System.put_env("TEST_REQUIRED", "value")
      assert required!("TEST_REQUIRED") == "value"
    end

    test "raises when environment variable is not set" do
      assert_raise System.EnvError, fn ->
        required!("TEST_REQUIRED")
      end
    end

    test "returns empty string when variable is set to empty string" do
      System.put_env("TEST_REQUIRED", "")
      assert required!("TEST_REQUIRED") == ""
    end
  end

  describe "integer!/1" do
    test "converts positive integers" do
      assert integer!("42") == 42
      assert integer!("0") == 0
      assert integer!("999") == 999
    end

    test "converts negative integers" do
      assert integer!("-42") == -42
      assert integer!("-1") == -1
    end

    test "raises on invalid integer strings" do
      assert_raise ArgumentError, ~s(could not convert "not a number" to integer), fn ->
        integer!("not a number")
      end

      assert_raise ArgumentError, ~s(could not convert "3.14" to integer), fn ->
        integer!("3.14")
      end

      assert_raise ArgumentError, ~s(could not convert "42x" to integer), fn ->
        integer!("42x")
      end
    end

    test "raises on nil" do
      assert_raise ArgumentError, "cannot convert nil to integer", fn ->
        integer!(nil)
      end
    end

    test "raises on empty string" do
      assert_raise ArgumentError, ~s(could not convert "" to integer), fn ->
        integer!("")
      end
    end
  end

  describe "float!/1" do
    test "converts float strings" do
      assert float!("3.14") == 3.14
      assert float!("-2.5") == -2.5
      assert float!("0.0") == 0.0
    end

    test "converts integer strings to floats" do
      assert float!("42") == 42.0
      assert float!("-10") == -10.0
    end

    test "raises on invalid float strings" do
      assert_raise ArgumentError, ~s(could not convert "not a number" to float), fn ->
        float!("not a number")
      end

      assert_raise ArgumentError, ~s(could not convert "3.14.15" to float), fn ->
        float!("3.14.15")
      end
    end

    test "raises on nil" do
      assert_raise ArgumentError, "cannot convert nil to float", fn ->
        float!(nil)
      end
    end

    test "raises on empty string" do
      assert_raise ArgumentError, ~s(could not convert "" to float), fn ->
        float!("")
      end
    end
  end

  describe "boolean!/1" do
    test "converts true variations (case-insensitive)" do
      assert boolean!("true") == true
      assert boolean!("TRUE") == true
      assert boolean!("True") == true
      assert boolean!("1") == true
      assert boolean!("yes") == true
      assert boolean!("YES") == true
      assert boolean!("on") == true
      assert boolean!("ON") == true
    end

    test "converts false variations (case-insensitive)" do
      assert boolean!("false") == false
      assert boolean!("FALSE") == false
      assert boolean!("False") == false
      assert boolean!("0") == false
      assert boolean!("no") == false
      assert boolean!("NO") == false
      assert boolean!("off") == false
      assert boolean!("OFF") == false
    end

    test "raises on invalid boolean strings" do
      assert_raise ArgumentError, ~s(could not convert "maybe" to boolean), fn ->
        boolean!("maybe")
      end

      assert_raise ArgumentError, ~s(could not convert "2" to boolean), fn ->
        boolean!("2")
      end

      assert_raise ArgumentError, ~s(could not convert "y" to boolean), fn ->
        boolean!("y")
      end
    end

    test "raises on nil" do
      assert_raise ArgumentError, "cannot convert nil to boolean", fn ->
        boolean!(nil)
      end
    end

    test "raises on empty string" do
      assert_raise ArgumentError, ~s(could not convert "" to boolean), fn ->
        boolean!("")
      end
    end
  end

  describe "atom!/1" do
    test "converts to existing atoms" do
      # These atoms exist
      assert atom!("info") == :info
      assert atom!("error") == :error
      assert atom!("ok") == :ok
    end

    test "raises when atom does not exist" do
      assert_raise ArgumentError, ~s(atom "nonexistent_atom_xyz_12345" does not exist), fn ->
        atom!("nonexistent_atom_xyz_12345")
      end
    end

    test "raises on nil" do
      assert_raise ArgumentError, "cannot convert nil to atom", fn ->
        atom!(nil)
      end
    end
  end

  describe "list!/1" do
    test "splits on comma by default" do
      assert list!("a,b,c") == ["a", "b", "c"]
    end

    test "trims whitespace by default" do
      assert list!("a, b, c") == ["a", "b", "c"]
      assert list!(" a , b , c ") == ["a", "b", "c"]
    end

    test "handles empty string" do
      assert list!("") == [""]
    end

    test "handles single element" do
      assert list!("single") == ["single"]
    end

    test "accepts custom delimiter" do
      assert list!("x:y:z", delimiter: ":") == ["x", "y", "z"]
      assert list!("a|b|c", delimiter: "|") == ["a", "b", "c"]
    end

    test "respects trim option" do
      assert list!(" a , b , c ", trim: false) == [" a ", " b ", " c "]
      assert list!("a,b,c", trim: false) == ["a", "b", "c"]
    end

    test "can combine delimiter and trim options" do
      assert list!(" a : b : c ", delimiter: ":", trim: true) == ["a", "b", "c"]
    end

    test "raises on nil" do
      assert_raise ArgumentError, "cannot convert nil to list", fn ->
        list!(nil)
      end
    end
  end

  describe "list!/2 with transformer" do
    test "transforms each element with integer!" do
      assert list!("1,2,3", &integer!/1) == [1, 2, 3]
      assert list!("10,20,30", &integer!/1) == [10, 20, 30]
    end

    test "transforms each element with float!" do
      assert list!("3.14,2.71,1.41", &float!/1) == [3.14, 2.71, 1.41]
    end

    test "transforms each element with boolean!" do
      assert list!("true,false,yes,no", &boolean!/1) == [true, false, true, false]
    end

    test "works with custom delimiter" do
      assert list!("1:2:3", &integer!/1, delimiter: ":") == [1, 2, 3]
    end

    test "raises if transformer raises" do
      assert_raise ArgumentError, fn ->
        list!("1,not_a_number,3", &integer!/1)
      end
    end

    test "raises on nil" do
      assert_raise ArgumentError, "cannot convert nil to list", fn ->
        list!(nil, &integer!/1)
      end
    end
  end

  describe "interval!/1 and interval!/2" do
    test "parses plain numbers as milliseconds" do
      assert interval!("300") == 300
      assert interval!("1000") == 1000
      assert interval!("0") == 0
      assert interval!("5000") == 5000
    end

    test "parses plain decimal numbers as milliseconds" do
      assert interval!("100.5") == 100
      assert interval!("999.9") == 999
    end

    test "defaults to milliseconds (like :timer module)" do
      assert interval!("1s") == 1000
      assert interval!("30s") == 30_000
      assert interval!("5m") == 300_000
      assert interval!("2h") == 7_200_000
      assert interval!("100ms") == 100
    end

    test "parses seconds to milliseconds" do
      assert interval!("1s", :milliseconds) == 1000
      assert interval!("30s", :milliseconds) == 30_000
      assert interval!("0s", :milliseconds) == 0
    end

    test "parses minutes to seconds" do
      assert interval!("1m", :seconds) == 60
      assert interval!("5m", :seconds) == 300
    end

    test "parses hours to minutes" do
      assert interval!("1h", :minutes) == 60
      assert interval!("2h", :minutes) == 120
    end

    test "parses days to hours" do
      assert interval!("1d", :hours) == 24
      assert interval!("7d", :hours) == 168
    end

    test "parses milliseconds" do
      assert interval!("100ms", :milliseconds) == 100
      assert interval!("1000ms", :seconds) == 1
    end

    test "handles decimal values" do
      assert interval!("1.5s", :milliseconds) == 1500
      assert interval!("2.5m", :seconds) == 150
      assert interval!("0.5h", :minutes) == 30
    end

    test "converts between different units" do
      assert interval!("1m", :milliseconds) == 60_000
      assert interval!("1h", :seconds) == 3600
      assert interval!("1d", :minutes) == 1440
    end

    test "converts plain numbers to custom units" do
      assert interval!("30000", :seconds) == 30
      assert interval!("60000", :minutes) == 1
      assert interval!("3600000", :hours) == 1
    end

    test "raises on invalid interval format" do
      assert_raise ArgumentError, ~s(could not parse interval "invalid"), fn ->
        interval!("invalid", :seconds)
      end

      assert_raise ArgumentError, ~s(could not parse interval "s"), fn ->
        interval!("s", :seconds)
      end

      assert_raise ArgumentError, ~s(could not parse interval "123x"), fn ->
        interval!("123x")
      end
    end

    test "raises on unsupported unit" do
      assert_raise ArgumentError, ~s(unsupported interval unit: :weeks), fn ->
        interval!("1d", :weeks)
      end
    end

    test "raises on nil with default unit" do
      assert_raise ArgumentError, "cannot convert nil to interval", fn ->
        interval!(nil)
      end
    end

    test "raises on nil with explicit unit" do
      assert_raise ArgumentError, "cannot convert nil to interval", fn ->
        interval!(nil, :seconds)
      end
    end
  end

  describe "uri!/1" do
    test "parses HTTP URIs" do
      uri = uri!("https://example.com:8080/path?query=value")
      assert uri.scheme == "https"
      assert uri.host == "example.com"
      assert uri.port == 8080
      assert uri.path == "/path"
      assert uri.query == "query=value"
    end

    test "parses database URIs" do
      uri = uri!("postgresql://localhost/mydb")
      assert uri.scheme == "postgresql"
      assert uri.host == "localhost"
      assert uri.path == "/mydb"
    end

    test "parses simple URIs" do
      uri = uri!("http://localhost")
      assert uri.scheme == "http"
      assert uri.host == "localhost"
    end

    test "parses URIs with userinfo" do
      uri = uri!("postgres://user:pass@localhost:5432/db")
      assert uri.scheme == "postgres"
      assert uri.userinfo == "user:pass"
      assert uri.host == "localhost"
      assert uri.port == 5432
      assert uri.path == "/db"
    end

    test "raises on invalid URI" do
      assert_raise ArgumentError, ~s(could not parse URI "ht!tp://invalid"), fn ->
        uri!("ht!tp://invalid")
      end
    end

    test "raises on nil" do
      assert_raise ArgumentError, "cannot convert nil to URI", fn ->
        uri!(nil)
      end
    end
  end

  describe "ip!/1" do
    test "parses IPv4 addresses" do
      assert ip!("127.0.0.1") == {127, 0, 0, 1}
      assert ip!("0.0.0.0") == {0, 0, 0, 0}
      assert ip!("192.168.1.1") == {192, 168, 1, 1}
      assert ip!("255.255.255.255") == {255, 255, 255, 255}
    end

    test "parses IPv6 addresses" do
      assert ip!("::1") == {0, 0, 0, 0, 0, 0, 0, 1}
      assert ip!("::") == {0, 0, 0, 0, 0, 0, 0, 0}
      assert ip!("2001:db8::8a2e:370:7334") == {8193, 3512, 0, 0, 0, 35374, 880, 29492}
      assert ip!("fe80::1") == {65152, 0, 0, 0, 0, 0, 0, 1}
    end

    test "raises on invalid IP addresses" do
      assert_raise ArgumentError, ~s(could not parse IP address "not an ip"), fn ->
        ip!("not an ip")
      end

      assert_raise ArgumentError, ~s(could not parse IP address "256.256.256.256"), fn ->
        ip!("256.256.256.256")
      end

      assert_raise ArgumentError, ~s(could not parse IP address ""), fn ->
        ip!("")
      end
    end

    test "raises on nil" do
      assert_raise ArgumentError, "cannot convert nil to IP address", fn ->
        ip!(nil)
      end
    end
  end
end
