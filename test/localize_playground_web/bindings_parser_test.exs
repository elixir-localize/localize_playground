defmodule LocalizePlaygroundWeb.BindingsParserTest do
  use ExUnit.Case, async: true
  doctest LocalizePlaygroundWeb.BindingsParser

  alias LocalizePlaygroundWeb.BindingsParser

  describe "accepted input — literals only" do
    test "empty input → empty map" do
      assert {:ok, %{}} = BindingsParser.parse("")
      assert {:ok, %{}} = BindingsParser.parse("   \n  ")
    end

    test "empty map literal" do
      assert {:ok, %{}} = BindingsParser.parse("%{}")
    end

    test "map with an integer value" do
      assert {:ok, %{count: 3}} = BindingsParser.parse("%{count: 3}")
    end

    test "map with string, atom, boolean, nil values" do
      assert {:ok, %{name: "Ada", role: :admin, active: true, seen: nil}} =
               BindingsParser.parse(~s|%{name: "Ada", role: :admin, active: true, seen: nil}|)
    end

    test "keyword list" do
      assert {:ok, [count: 3]} = BindingsParser.parse("[count: 3]")
    end

    test "keyword list with multiple entries" do
      assert {:ok, [count: 3, name: "Ada", tags: ["a", "b"]]} =
               BindingsParser.parse(~s|[count: 3, name: "Ada", tags: ["a", "b"]]|)
    end

    test "nested map inside a map" do
      assert {:ok, %{nested: %{value: 42}}} =
               BindingsParser.parse("%{nested: %{value: 42}}")
    end

    test "nested keyword list inside a map" do
      assert {:ok, %{items: [a: 1, b: 2]}} =
               BindingsParser.parse("%{items: [a: 1, b: 2]}")
    end

    test "negative integer literals" do
      assert {:ok, %{n: -42}} = BindingsParser.parse("%{n: -42}")
    end

    test "negative float literals" do
      assert {:ok, %{x: -3.14}} = BindingsParser.parse("%{x: -3.14}")
    end

    test "tuples of literals" do
      assert {:ok, %{coord: {1, 2, 3}}} = BindingsParser.parse("%{coord: {1, 2, 3}}")
    end

    test "lists of strings" do
      assert {:ok, %{tags: ["a", "b", "c"]}} =
               BindingsParser.parse(~s|%{tags: ["a", "b", "c"]}|)
    end

    test "~D sigil (Date)" do
      assert {:ok, %{due: ~D[2026-12-31]}} =
               BindingsParser.parse("%{due: ~D[2026-12-31]}")
    end

    test "~U sigil (UTC DateTime)" do
      assert {:ok, %{at: ~U[2026-12-31T23:59:59Z]}} =
               BindingsParser.parse("%{at: ~U[2026-12-31T23:59:59Z]}")
    end

    test "~N sigil (NaiveDateTime)" do
      assert {:ok, %{seen: ~N[2026-12-31 23:59:59]}} =
               BindingsParser.parse("%{seen: ~N[2026-12-31 23:59:59]}")
    end
  end

  describe "rejected input — sigils other than ~D/~U/~N" do
    test "~r regex sigil" do
      assert {:error, message} = BindingsParser.parse("%{p: ~r/[a-z]+/}")
      assert message =~ "~r sigil"
      assert message =~ "only ~D, ~U, ~N are allowed"
    end

    test "~w word-list sigil" do
      assert {:error, message} = BindingsParser.parse("%{items: ~w(a b c)}")
      assert message =~ "~w sigil"
    end

    test "~s string sigil (interpolating)" do
      # The parser sometimes inlines ~s with a literal body into a
      # plain binary (no AST sigil node), so this is only testable
      # with something that forces the sigil to survive to AST —
      # e.g. interpolation. Matches the "sigil with modifiers" OR
      # "~s sigil" rejection paths depending on how Elixir represents it.
      assert {:error, message} = BindingsParser.parse(~S<%{x: ~s(hi #{secret})}>)
      assert message =~ "literal values" or message =~ "Could not parse"
    end

    test "~T time sigil (not in the whitelist)" do
      assert {:error, message} = BindingsParser.parse("%{t: ~T[12:00:00]}")
      assert message =~ "~T sigil"
    end
  end

  describe "rejected input — no code execution" do
    test "function call in value position" do
      # The canonical RCE gadget. If this passes, the whole server
      # is reachable from the playground's websocket.
      assert {:error, message} =
               BindingsParser.parse(~s|%{x: File.read!("/etc/passwd")}|)

      assert message =~ "literal values"
      assert message =~ "function call or module reference"
    end

    test "bare function call outside any container" do
      assert {:error, message} = BindingsParser.parse("System.version()")
      assert message =~ "literal values"
    end

    test "variable reference" do
      assert {:error, message} = BindingsParser.parse("%{x: some_var}")
      assert message =~ "literal values"
      assert message =~ "variable"
    end

    test "operator (arithmetic)" do
      assert {:error, message} = BindingsParser.parse("%{x: 1 + 2}")
      assert message =~ "literal values"
    end

    test "module reference (constant lookup)" do
      assert {:error, message} = BindingsParser.parse("%{x: MyMod.constant}")
      assert message =~ "literal values"
    end

    test "pipe chain" do
      assert {:error, message} =
               BindingsParser.parse("%{x: \"hello\" |> String.upcase()}")

      assert message =~ "literal values"
    end

    test "anonymous function" do
      assert {:error, message} = BindingsParser.parse("%{x: fn -> 42 end}")
      assert message =~ "literal values"
    end

    test "if/else (control flow)" do
      assert {:error, message} =
               BindingsParser.parse("%{x: if(true, do: 1, else: 2)}")

      assert message =~ "literal values"
    end

    test "string interpolation (which compiles to a function call)" do
      # `~S<...>` keeps `#{...}` literal so the parser sees it, not us.
      # Angle-bracket delimiter avoids paren/brace balancing issues.
      assert {:error, message} = BindingsParser.parse(~S<%{x: "hello #{inspect(:world)}"}>)
      assert message =~ "literal values"
    end

    test "atom-exhaustion DoS via String.to_atom — not even parseable as literal" do
      # This wouldn't be accepted anyway (String.to_atom is a function
      # call). The test here is a belt-and-braces confirmation that
      # input designed to exhaust the atom table never reaches an
      # atom-creating code path.
      assert {:error, _} = BindingsParser.parse(~s|%{x: String.to_atom("attack")}|)
    end

    test "file open + read + System.cmd (the three classic exfil paths)" do
      for payload <- [
            ~s|%{x: File.open!("/etc/passwd")}|,
            ~s|%{x: File.read!("/etc/passwd")}|,
            ~s|%{x: System.cmd("ls", ["/"])}|,
            ~s|%{x: :os.cmd(~c"ls /")}|
          ] do
        assert {:error, message} = BindingsParser.parse(payload), payload
        assert message =~ "literal values", payload
      end
    end
  end

  describe "rejected shape — parses but isn't a map or keyword list" do
    test "bare integer" do
      assert {:error, message} = BindingsParser.parse("42")
      assert message =~ "must evaluate to a map or keyword list"
    end

    test "bare string" do
      assert {:error, message} = BindingsParser.parse(~s|"hello"|)
      assert message =~ "must evaluate to a map or keyword list"
    end

    test "list of integers (not a keyword list)" do
      assert {:error, message} = BindingsParser.parse("[1, 2, 3]")
      assert message =~ "must evaluate to a map or keyword list"
    end
  end

  describe "rejected input — syntax errors" do
    test "unclosed map" do
      assert {:error, message} = BindingsParser.parse("%{count: 3")
      assert message =~ "Could not parse bindings"
    end

    test "trailing comma in the wrong place" do
      # Actually trailing commas in maps are accepted by Elixir's parser.
      # Use a genuinely invalid input instead.
      assert {:error, message} = BindingsParser.parse("%{ = }")
      assert message =~ "Could not parse bindings"
    end
  end
end
