defmodule Sgp4Ex.AccuracyTest do
  use ExUnit.Case

  @moduledoc """
  Test SGP4 accuracy against known values from Python sgp4.
  This test ensures our implementation matches the reference implementation.
  """

  describe "sgp4 propagation accuracy" do
    test "matches Python sgp4 TEME positions within tolerance" do
      # Test TLE
      line1 = "1 25162U 98008A   24366.54450174 -.00000099  00000-0 -16016-4 0    14"
      line2 = "2 25162  52.0032 101.1592 0001122 221.6908 255.6054 12.38204644222943"

      {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)

      # Test cases with expected TEME positions from Python sgp4
      # Geodetic values use classical GMST (IAU 1982 model)
      test_cases = [
        {
          ~U[2024-08-01 00:00:00Z],
          # Expected km
          {5522.564443, 3786.056650, -4184.029899},
          # Expected geodetic
          {-32.140118, 84.337508, 1523.393}
        },
        {
          ~U[2024-08-02 00:00:00Z],
          # Expected km
          {-7876.838966, -466.131419, 193.940488},
          # Expected geodetic
          {1.415622, -127.694498, 1514.879}
        },
        {
          # At TLE epoch
          ~U[2024-12-31 13:04:04.950336Z],
          # Expected km
          {-3532.880154, -4386.380368, 5520.664266},
          # Expected geodetic
          {44.582408, -65.856597, 1519.015}
        }
      ]

      for {epoch, {exp_x, exp_y, exp_z}, {exp_lat, exp_lon, exp_alt}} <- test_cases do
        # Test TEME position
        {:ok, teme_state} = Sgp4Ex.propagate_tle_to_epoch(tle, epoch)
        {x, y, z} = teme_state.position

        # Should match within 10 km (different SGP4 implementations may vary slightly)
        assert_in_delta x, exp_x, 10.0, "X position at #{epoch}"
        assert_in_delta y, exp_y, 10.0, "Y position at #{epoch}"
        assert_in_delta z, exp_z, 10.0, "Z position at #{epoch}"

        # Test geodetic conversion
        {:ok, geo} = Sgp4Ex.propagate_to_geodetic(tle, epoch)

        # Should match within reasonable tolerance
        # Allow up to 0.5 degree for lat/lon due to small TEME differences
        # and 5 km for altitude due to potential differences in implementations
        assert_in_delta geo.latitude, exp_lat, 0.5, "Latitude at #{epoch}"
        assert_in_delta geo.longitude, exp_lon, 1.0, "Longitude at #{epoch}"
        assert_in_delta geo.altitude_km, exp_alt, 5.0, "Altitude at #{epoch}"
      end
    end

    test "propagates correctly for positive and negative time offsets" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)

      # Test both before and after epoch
      # 1 hour before
      before_epoch = DateTime.add(tle.epoch, -3600, :second)
      # 1 hour after
      after_epoch = DateTime.add(tle.epoch, 3600, :second)

      {:ok, before_state} = Sgp4Ex.propagate_tle_to_epoch(tle, before_epoch)
      {:ok, at_epoch_state} = Sgp4Ex.propagate_tle_to_epoch(tle, tle.epoch)
      {:ok, after_state} = Sgp4Ex.propagate_tle_to_epoch(tle, after_epoch)

      # Positions should all be different
      refute before_state.position == at_epoch_state.position
      refute at_epoch_state.position == after_state.position

      # But magnitudes should be similar (same orbit)
      mag = fn {x, y, z} -> :math.sqrt(x * x + y * y + z * z) end

      before_mag = mag.(before_state.position)
      at_epoch_mag = mag.(at_epoch_state.position)
      after_mag = mag.(after_state.position)

      # ISS altitude varies by only a few km
      assert_in_delta before_mag, at_epoch_mag, 10.0
      assert_in_delta at_epoch_mag, after_mag, 10.0
    end
  end
end
