defmodule Envious.BackwardsCompatTest do
  use ExUnit.Case, async: true

  describe "Envious.Helpers backward compatibility" do
    test "functions delegate to Envious.Env" do
      System.put_env("TEST_COMPAT", "42")

      # Test that Envious.Helpers still works
      assert Envious.Helpers.optional("TEST_COMPAT") == "42"
      assert Envious.Helpers.integer!("100") == 100
      assert Envious.Helpers.boolean!("true") == true

      System.delete_env("TEST_COMPAT")
    end
  end

  describe "use Envious" do
    test "imports both Envious and Envious.Env" do
      # This test verifies the macro expands correctly
      Code.compile_quoted(
        quote do
          defmodule TestUseEnvious do
            use Envious

            def test_parse do
              parse!("KEY=value")
            end

            def test_env do
              optional("MISSING", "default")
            end
          end
        end
      )

      assert TestUseEnvious.test_parse() == %{"KEY" => "value"}
      assert TestUseEnvious.test_env() == "default"
    end
  end
end
