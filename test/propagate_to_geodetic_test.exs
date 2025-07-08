defmodule Sgp4Ex.PropagateToGeodeticTest do
  use ExUnit.Case

  describe "propagate_to_geodetic/2" do
    test "converts ISS position to geodetic coordinates" do
      # Real ISS TLE
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      epoch = ~U[2021-10-02 14:00:00Z]

      assert {:ok, geodetic} = Sgp4Ex.propagate_to_geodetic(tle, epoch)

      # Verify the result structure
      assert Map.has_key?(geodetic, :latitude)
      assert Map.has_key?(geodetic, :longitude)
      assert Map.has_key?(geodetic, :altitude_km)

      # Verify reasonable values for ISS
      # Within inclination
      assert geodetic.latitude >= -51.6456 and geodetic.latitude <= 51.6456
      assert geodetic.longitude >= -180 and geodetic.longitude <= 180
      # Typical ISS altitude
      assert geodetic.altitude_km >= 400 and geodetic.altitude_km <= 450
    end

    test "handles propagation errors gracefully" do
      # Create a TLE that will cause propagation errors (invalid mean motion)
      {:ok, tle} =
        Sgp4Ex.parse_tle(
          "1 00000U 00000A   00001.00000000  .00000000  00000-0  00000-0 0    00",
          "2 00000  00.0000 000.0000 0000000  00.0000 000.0000 00.00000000    00"
        )

      epoch = ~U[2021-10-02 14:00:00Z]

      assert {:error, _reason} = Sgp4Ex.propagate_to_geodetic(tle, epoch)
    end

    test "produces consistent results for same input" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
      epoch = ~U[2021-10-02 14:00:00Z]

      # Run twice
      {:ok, result1} = Sgp4Ex.propagate_to_geodetic(tle, epoch)
      {:ok, result2} = Sgp4Ex.propagate_to_geodetic(tle, epoch)

      # Should be identical
      assert result1.latitude == result2.latitude
      assert result1.longitude == result2.longitude
      assert result1.altitude_km == result2.altitude_km
    end

    test "handles different epochs correctly" do
      line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"

      {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)

      # Test at TLE epoch
      tle_epoch = tle.epoch
      {:ok, at_epoch} = Sgp4Ex.propagate_to_geodetic(tle, tle_epoch)

      # Test 1 hour later
      one_hour_later = DateTime.add(tle_epoch, 3600, :second)
      {:ok, later} = Sgp4Ex.propagate_to_geodetic(tle, one_hour_later)

      # Position should have changed (ISS orbits Earth in ~90 minutes)
      refute_in_delta at_epoch.latitude, later.latitude, 0.1
      refute_in_delta at_epoch.longitude, later.longitude, 0.1

      # Altitude should be similar (circular orbit)
      # Allow up to 20km variation due to orbital dynamics
      assert_in_delta at_epoch.altitude_km, later.altitude_km, 20.0
    end
  end
end
