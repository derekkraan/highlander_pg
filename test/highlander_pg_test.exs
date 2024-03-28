defmodule HighlanderPgTest do
  use ExUnit.Case
  doctest HighlanderPg

  test "greets the world" do
    assert HighlanderPg.hello() == :world
  end
end
