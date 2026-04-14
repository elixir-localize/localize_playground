defmodule LocalizePlaygroundTest do
  use ExUnit.Case
  doctest LocalizePlayground

  test "greets the world" do
    assert LocalizePlayground.hello() == :world
  end
end
