defmodule LocalizePlaygroundWeb.MessagesPresetsTest do
  use ExUnit.Case, async: true

  alias LocalizePlaygroundWeb.BindingsParser
  alias LocalizePlaygroundWeb.MessagesLive

  # The Messages tab ships its default message and example presets as
  # static module data, and nothing else formats them. An invalid preset
  # therefore used to surface only as a runtime error in the browser —
  # which is how a self-referencing `.local $count = {$count :number}`
  # reached production. These tests walk the same path the LiveView does:
  # `BindingsParser.parse/1`, then `Localize.Message.format/3`.

  describe "presets/0" do
    test "returns the default plus every example" do
      presets = MessagesLive.presets()

      assert length(presets) > 1
      assert %{name: "Default"} = hd(presets)

      for preset <- presets do
        assert %{name: name, message: message, bindings: bindings} = preset
        assert is_binary(name) and name != ""
        assert is_binary(message) and message != ""
        assert is_binary(bindings)
      end
    end
  end

  describe "every preset is usable" do
    test "bindings parse" do
      for %{name: name, bindings: bindings} <- MessagesLive.presets() do
        assert {:ok, value} = BindingsParser.parse(bindings),
               "bindings for preset #{inspect(name)} do not parse"

        assert is_map(value) or is_list(value),
               "bindings for preset #{inspect(name)} are not a map or keyword list"
      end
    end

    test "messages format to a non-empty string" do
      for %{name: name, message: message, bindings: bindings} <- MessagesLive.presets() do
        {:ok, values} = BindingsParser.parse(bindings)

        case Localize.Message.format(message, values) do
          {:ok, output} ->
            refute output == "", "preset #{inspect(name)} formatted to an empty string"

          {:error, reason} ->
            flunk("preset #{inspect(name)} failed to format: #{inspect(reason)}")
        end
      end
    end

    test "messages format in a non-default locale too" do
      # Catches a preset that only works because `en` happens to have the
      # plural category or pattern its selectors rely on.
      for %{name: name, message: message, bindings: bindings} <- MessagesLive.presets() do
        {:ok, values} = BindingsParser.parse(bindings)

        assert {:ok, _output} = Localize.Message.format(message, values, locale: :de),
               "preset #{inspect(name)} failed to format for :de"
      end
    end
  end

  describe "MF2 declaration rules" do
    # Guards the specific mistake this test file was added for: a `.local`
    # declaration may not read the variable it declares. `.input` is the
    # construct for annotating an external variable with a function.
    test "a self-referencing .local is a duplicate declaration" do
      message = """
      .local $count = {$count :number}
      .match $count
      * {{You have {$count} unread messages.}}
      """

      assert {:error, %{reason: :duplicate_declaration, detail: "count"}} =
               Localize.Message.format(message, %{count: 1})
    end

    test ".input annotates an external variable without redeclaring it" do
      message = """
      .input {$count :number}
      .match $count
      0 {{You have no unread messages.}}
      1 {{You have one unread message.}}
      * {{You have {$count} unread messages.}}
      """

      assert {:ok, "You have no unread messages."} =
               Localize.Message.format(message, %{count: 0})

      assert {:ok, "You have one unread message."} =
               Localize.Message.format(message, %{count: 1})

      assert {:ok, "You have 1,234 unread messages."} =
               Localize.Message.format(message, %{count: 1234})
    end

    test "no preset declares a local that reads itself" do
      # A cheap structural check across every preset, so a new one cannot
      # reintroduce the pattern even if it happens to format for :en.
      for %{name: name, message: message} <- MessagesLive.presets() do
        refute Regex.match?(~r/\.local\s+\$([a-zA-Z_]\w*)\s*=\s*\{\s*\$\1\b/, message),
               "preset #{inspect(name)} declares a local that reads itself; use .input"
      end
    end
  end
end
