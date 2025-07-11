defmodule Sgp4Ex.SkyfieldRegressionTest do
  use ExUnit.Case

  @moduledoc """
  Regression test to ensure we exactly match Python Skyfield results.
  This test case was working before and should work again.
  """

  # Test data
  @line1 "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
  @line2 "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"
  @datetime ~U[2024-03-15 12:00:00Z]

  # Python Skyfield reference values (always uses IAU 2000A)
  @skyfield_lat -50.39847319815834
  @skyfield_lon 172.14031164763892
  @skyfield_alt 436.5103397439415

  test "IAU 2000A mode should exactly match Python Skyfield" do
    {:ok, tle} = Sgp4Ex.parse_tle(@line1, @line2)
    {:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, @datetime, use_iau2000a: true)

    # Should match within excellent tolerance (sub-arcsecond latitude, few arcseconds longitude)
    assert_in_delta result.latitude, @skyfield_lat, 0.000001, "IAU 2000A latitude mismatch vs Skyfield"
    assert_in_delta result.longitude, @skyfield_lon, 0.002, "IAU 2000A longitude mismatch vs Skyfield" 
    assert_in_delta result.altitude_km, @skyfield_alt, 0.001, "IAU 2000A altitude mismatch vs Skyfield"
  end

  test "GMST mode should be significantly different from Skyfield" do
    {:ok, tle} = Sgp4Ex.parse_tle(@line1, @line2)
    {:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, @datetime, use_iau2000a: false)

    # GMST should be notably different (less accurate)
    lon_diff = abs(result.longitude - @skyfield_lon)
    assert lon_diff > 0.1, "GMST should differ significantly from Skyfield IAU 2000A (got #{lon_diff}° difference)"
  end

  test "default mode should match Skyfield (uses IAU 2000A by default)" do
    {:ok, tle} = Sgp4Ex.parse_tle(@line1, @line2)
    {:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, @datetime)

    # Default should match Skyfield within excellent tolerance
    assert_in_delta result.latitude, @skyfield_lat, 0.000001, "Default latitude mismatch vs Skyfield"
    assert_in_delta result.longitude, @skyfield_lon, 0.002, "Default longitude mismatch vs Skyfield" 
    assert_in_delta result.altitude_km, @skyfield_alt, 0.001, "Default altitude mismatch vs Skyfield"
  end
end