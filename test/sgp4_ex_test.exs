defmodule Sgp4ExTest do
  use ExUnit.Case
  doctest Sgp4Ex

  test "nif compilation" do
    # Check if the NIF module is loaded
    assert Code.ensure_loaded?(SGP4NIF)
  end
  test "propagate_tle/3 function" do
    # Check if the propagate_tle function is defined
    assert function_exported?(SGP4NIF, :propagate_tle, 3)
  end
end
