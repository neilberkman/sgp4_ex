defmodule Sgp4ExTest do
  use ExUnit.Case

  test "NIF is loaded" do
    assert Code.ensure_loaded?(SGP4NIF)
  end

  test "parse TLE" do
    line1 = "1 25544U 98067A   21275.12345678  .00001234  00000-0  12345-6 0  9993"
    line2 = "2 25544  51.6445 123.4567 0001234 123.4567 234.5678 15.50123467    12"

    {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
    assert tle.catalog_number == "25544"
    assert tle.classification == "U"
    assert tle.international_designator == "98067A"
    assert_in_delta tle.mean_motion_dot, 0.00001234 / 2.0, 1.0e-5
    assert tle.eccentricity == 0.0001234
  end

  test "propagate TLE to datetime" do
    line1 = "1 25544U 98067A   21275.12345678  .00001234  00000-0  12345-6 0  9993"
    line2 = "2 25544  51.6445 123.4567 0001234 123.4567 234.5678 15.50123467    12"

    {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
    datetime = DateTime.add(tle.epoch, 1, :day)
    {:ok, state} = Sgp4Ex.propagate_tle_to_datetime(tle, datetime)

    assert is_tuple(state.position)
    assert is_tuple(state.velocity)
    assert tuple_size(state.position) == 3
  end

  test "TEME to GCRS" do
    teme = %{
      position: {3700.211211203995390, 2015.912218120605530, 5309.513078070447591},
      velocity: {-3.398428894395407, 6.869656830559572, -0.239850181126689}
    }

    gcrs = Sgp4Ex.teme_to_gcrs(teme, {{2018, 7, 4}, {0, 0, 0}})

    assert is_tuple(gcrs.position)
    assert is_tuple(gcrs.velocity)
    # Smoke check: magnitude should be preserved (rotation doesn't change magnitude)
    teme_mag = :math.sqrt(elem(teme.position, 0) ** 2 + elem(teme.position, 1) ** 2 + elem(teme.position, 2) ** 2)
    gcrs_mag = :math.sqrt(elem(gcrs.position, 0) ** 2 + elem(gcrs.position, 1) ** 2 + elem(gcrs.position, 2) ** 2)
    assert_in_delta teme_mag, gcrs_mag, 0.01
  end
end
