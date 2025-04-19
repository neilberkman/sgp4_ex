defmodule Sgp4ExTest do
  use ExUnit.Case
  doctest Sgp4Ex

  test "nif compilation" do
    # Check if the NIF module is loaded
    assert Code.ensure_loaded?(SGP4NIF)
  end

  test "propagate tle" do
    # Example TLE data for the ISS
    line1 = "1 25544U 98067A   21275.12345678  .00001234  00000-0  12345-6 0  9993"
    line2 = "2 25544  51.6445 123.4567 0001234 123.4567 234.5678 15.50123467    12"
    tsince = 120.0

    # Call the NIF function
    result = SGP4NIF.propagate_tle(line1, line2, tsince)

    case result do
      {:ok, data} ->
        IO.inspect(data, label: "Data from NIF")
      {:error, reason} ->
        flunk("NIF returned error: #{inspect(reason)}")
      _ ->
        flunk("Unexpected result from NIF: #{inspect(result)}")
    end

    # Check if the result is a tuple with the expected structure
  end
end
