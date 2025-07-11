defmodule Sgp4Ex.AccuracyLockTest do
  use ExUnit.Case

  @moduledoc """
  Lock-in test to prevent accuracy regression.
  
  This test exactly verifies our achieved accuracy and will fail if any change
  degrades our performance. The tolerances here represent our best achieved
  accuracy after systematic optimization.
  """

  # Test case: ISS TLE and epoch from optimization work
  @line1 "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
  @line2 "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"
  @datetime ~U[2024-03-15 12:00:00Z]

  # Skyfield 1.53 reference values
  @skyfield_lat -50.39847319815834
  @skyfield_lon 172.14031164763892
  @skyfield_alt 436.5103397439415

  test "accuracy lock: exactly match our optimized performance" do
    {:ok, tle} = Sgp4Ex.parse_tle(@line1, @line2)
    {:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, @datetime, use_iau2000a: true)

    # Calculate errors
    lat_error_deg = abs(result.latitude - @skyfield_lat)
    lon_error_deg = abs(result.longitude - @skyfield_lon)
    alt_error_km = abs(result.altitude_km - @skyfield_alt)

    # Convert to standard units
    lat_error_arcsec = lat_error_deg * 3600.0
    lon_error_arcsec = lon_error_deg * 3600.0
    alt_error_m = alt_error_km * 1000.0

    # Document our achieved accuracy in test output
    IO.puts("\\n=== ACHIEVED ACCURACY VS SKYFIELD ===")
    IO.puts("Latitude error:  #{Float.round(lat_error_arcsec, 4)} arcseconds")
    IO.puts("Longitude error: #{Float.round(lon_error_arcsec, 2)} arcseconds")
    IO.puts("Altitude error:  #{Float.round(alt_error_m, 1)} meters")
    IO.puts("Ground track error: ~#{Float.round(:math.sqrt(lat_error_deg * lat_error_deg + lon_error_deg * lon_error_deg) * 111_320, 0)} meters")
    IO.puts("=======================================")

    # Lock in our achieved accuracy - these should never regress
    assert lat_error_arcsec < 0.002, "Latitude accuracy regressed beyond 0.002 arcsec"
    assert lon_error_arcsec < 5.0, "Longitude accuracy regressed beyond 5 arcsec"
    assert alt_error_m < 1.0, "Altitude accuracy regressed beyond 1 meter"

    # Verify exact results to prevent silent changes
    assert_in_delta result.latitude, @skyfield_lat, 0.000001, "Latitude changed unexpectedly"
    assert_in_delta result.longitude, @skyfield_lon, 0.002, "Longitude changed unexpectedly"
    assert_in_delta result.altitude_km, @skyfield_alt, 0.001, "Altitude changed unexpectedly"
  end

  test "default mode uses IAU 2000A and achieves same accuracy" do
    {:ok, tle} = Sgp4Ex.parse_tle(@line1, @line2)
    {:ok, result_explicit} = Sgp4Ex.propagate_to_geodetic(tle, @datetime, use_iau2000a: true)
    {:ok, result_default} = Sgp4Ex.propagate_to_geodetic(tle, @datetime)

    # Default should be identical to explicit IAU 2000A
    assert_in_delta result_default.latitude, result_explicit.latitude, 1.0e-10
    assert_in_delta result_default.longitude, result_explicit.longitude, 1.0e-10
    assert_in_delta result_default.altitude_km, result_explicit.altitude_km, 1.0e-10
  end

  test "GMST mode is significantly less accurate (as expected)" do
    {:ok, tle} = Sgp4Ex.parse_tle(@line1, @line2)
    {:ok, iau2000a_result} = Sgp4Ex.propagate_to_geodetic(tle, @datetime, use_iau2000a: true)
    {:ok, gmst_result} = Sgp4Ex.propagate_to_geodetic(tle, @datetime, use_iau2000a: false)

    iau2000a_lon_error = abs(iau2000a_result.longitude - @skyfield_lon)
    gmst_lon_error = abs(gmst_result.longitude - @skyfield_lon)

    # GMST should be much less accurate (confirming IAU 2000A value)
    assert gmst_lon_error > 0.1, "GMST mode should be significantly less accurate"
    assert iau2000a_lon_error < gmst_lon_error / 10, "IAU 2000A should be much more accurate"
  end
end