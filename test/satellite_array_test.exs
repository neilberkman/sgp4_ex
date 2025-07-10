defmodule Sgp4Ex.SatelliteArrayTest do
  use ExUnit.Case
  alias Sgp4Ex.SatelliteArray

  @iss_tle1 "1 25544U 98067A   24074.54761985  .00019515  00000+0  35063-3 0  9997"
  @iss_tle2 "2 25544  51.6410 299.5237 0005417  72.1189  36.3479 15.49802661443442"

  @starlink_tle1 "1 44238U 19029D   24074.87639601  .00001372  00000+0  10839-3 0  9996"
  @starlink_tle2 "2 44238  52.9985  63.8811 0001422  92.9286 267.2031 15.06391223267959"

  describe "propagate_to_geodetic/2" do
    test "propagates single satellite" do
      tles = [{@iss_tle1, @iss_tle2}]
      datetime = ~U[2024-03-15 12:00:00Z]

      results = SatelliteArray.propagate_to_geodetic(tles, datetime)

      assert length(results) == 1
      assert [{:ok, %{latitude: lat, longitude: lon, altitude_km: alt}}] = results

      # ISS orbital parameters - reasonable ranges
      # Inclination limits
      assert lat >= -51.6 and lat <= 51.6
      assert lon >= -180 and lon <= 180
      # ISS altitude range
      assert alt >= 300 and alt <= 500
    end

    test "propagates multiple satellites" do
      tles = [
        {@iss_tle1, @iss_tle2},
        {@starlink_tle1, @starlink_tle2}
      ]

      datetime = ~U[2024-03-15 12:00:00Z]

      results = SatelliteArray.propagate_to_geodetic(tles, datetime)

      assert length(results) == 2
      assert Enum.all?(results, &match?({:ok, %{latitude: _, longitude: _, altitude_km: _}}, &1))
    end

    test "handles invalid TLE" do
      invalid_tle = [
        {"invalid line 1", "invalid line 2"}
      ]

      datetime = ~U[2024-03-15 12:00:00Z]

      results = SatelliteArray.propagate_to_geodetic(invalid_tle, datetime)

      assert length(results) == 1
      assert [{:error, _reason}] = results
    end

    test "propagates with GPU coordinate transformations" do
      tles = [{@iss_tle1, @iss_tle2}]
      datetime = ~U[2024-03-15 12:00:00Z]

      # Test GPU coordinate transformations
      results = SatelliteArray.propagate_to_geodetic(tles, datetime, use_gpu_coords: true)

      assert length(results) == 1
      assert [{:ok, %{latitude: lat, longitude: lon, altitude_km: alt}}] = results

      # ISS orbital parameters - reasonable ranges
      # Inclination limits
      assert lat >= -51.6 and lat <= 51.6
      assert lon >= -180 and lon <= 180
      # ISS altitude range
      assert alt >= 300 and alt <= 500
    end

    test "propagates with SatelliteCache integration" do
      # Clear cache to start fresh
      Sgp4Ex.SatelliteCache.clear_cache()

      tles = [
        {@iss_tle1, @iss_tle2},
        {@starlink_tle1, @starlink_tle2}
      ]

      datetime = ~U[2024-03-15 12:00:00Z]

      # First call should populate cache
      results1 = SatelliteArray.propagate_to_geodetic(tles, datetime, use_cache: true)

      # Second call should use cache
      results2 = SatelliteArray.propagate_to_geodetic(tles, datetime, use_cache: true)

      assert length(results1) == 2
      assert length(results2) == 2

      # Results should be identical (cache working)
      assert results1 == results2

      # All should be successful
      assert Enum.all?(results1, &match?({:ok, %{latitude: _, longitude: _, altitude_km: _}}, &1))

      # Cache should show hits
      stats = Sgp4Ex.SatelliteCache.stats()
      assert stats.hits > 0, "Expected cache hits, got #{stats.hits}"
    end

    test "propagates with cache and GPU coordinates" do
      # Clear cache to start fresh
      Sgp4Ex.SatelliteCache.clear_cache()

      tles = [{@iss_tle1, @iss_tle2}]
      datetime = ~U[2024-03-15 12:00:00Z]

      # Test cache + GPU combination
      results =
        SatelliteArray.propagate_to_geodetic(tles, datetime,
          use_cache: true,
          use_gpu_coords: true
        )

      assert length(results) == 1
      assert [{:ok, %{latitude: lat, longitude: lon, altitude_km: alt}}] = results

      # ISS orbital parameters - reasonable ranges
      # Inclination limits
      assert lat >= -51.6 and lat <= 51.6
      assert lon >= -180 and lon <= 180
      # ISS altitude range
      assert alt >= 300 and alt <= 500
    end
  end

  describe "propagate_many_to_geodetic/2" do
    test "propagates multiple satellites to multiple epochs using stateful API" do
      tles = [
        {@iss_tle1, @iss_tle2},
        {@starlink_tle1, @starlink_tle2}
      ]

      epochs = [
        ~U[2024-03-15 12:00:00Z],
        ~U[2024-03-15 13:00:00Z],
        ~U[2024-03-15 14:00:00Z]
      ]

      results = SatelliteArray.propagate_many_to_geodetic(tles, epochs)

      # Should return 2 satellites x 3 epochs = 2 lists of 3 results each
      assert length(results) == 2
      assert Enum.all?(results, fn sat_results -> length(sat_results) == 3 end)

      # All results should be successful
      flat_results = List.flatten(results)

      assert Enum.all?(
               flat_results,
               &match?({:ok, %{latitude: _, longitude: _, altitude_km: _}}, &1)
             )
    end

    test "propagates with GPU coordinates using stateful API" do
      tles = [{@iss_tle1, @iss_tle2}]

      epochs = [
        ~U[2024-03-15 12:00:00Z],
        ~U[2024-03-15 13:00:00Z]
      ]

      results = SatelliteArray.propagate_many_to_geodetic(tles, epochs, use_gpu_coords: true)

      # Should return 1 satellite x 2 epochs = 1 list of 2 results
      assert length(results) == 1
      assert [sat_results] = results
      assert length(sat_results) == 2

      # All results should be successful
      assert Enum.all?(
               sat_results,
               &match?({:ok, %{latitude: _, longitude: _, altitude_km: _}}, &1)
             )
    end

    test "returns TEME states when to_geodetic is false" do
      tles = [{@iss_tle1, @iss_tle2}]

      epochs = [
        ~U[2024-03-15 12:00:00Z],
        ~U[2024-03-15 13:00:00Z]
      ]

      results = SatelliteArray.propagate_many_to_geodetic(tles, epochs, to_geodetic: false)

      # Should return 1 satellite x 2 epochs = 1 list of 2 results
      assert length(results) == 1
      assert [sat_results] = results
      assert length(sat_results) == 2

      # Results should be TEME states, not geodetic coordinates
      assert Enum.all?(sat_results, fn result ->
               match?({:ok, %{position: {_, _, _}, velocity: {_, _, _}}}, result)
             end)
    end

    test "handles invalid TLE gracefully" do
      invalid_tles = [{"invalid line 1", "invalid line 2"}]
      epochs = [~U[2024-03-15 12:00:00Z]]

      results = SatelliteArray.propagate_many_to_geodetic(invalid_tles, epochs)

      assert length(results) == 1
      assert [sat_results] = results
      assert length(sat_results) == 1
      assert [{:error, _reason}] = sat_results
    end

    test "propagates using direct NIF resources (Step 6 optimization)" do
      tles = [
        {@iss_tle1, @iss_tle2},
        {@starlink_tle1, @starlink_tle2}
      ]

      epochs = [
        ~U[2024-03-15 12:00:00Z],
        ~U[2024-03-15 13:00:00Z]
      ]

      results = SatelliteArray.propagate_many_to_geodetic(tles, epochs, use_direct_nif: true)

      # Should return 2 satellites x 2 epochs = 2 lists of 2 results each
      assert length(results) == 2
      assert Enum.all?(results, fn sat_results -> length(sat_results) == 2 end)

      # All results should be successful
      flat_results = List.flatten(results)

      assert Enum.all?(
               flat_results,
               &match?({:ok, %{latitude: _, longitude: _, altitude_km: _}}, &1)
             )
    end

    test "propagates using direct NIF with GPU coordinates" do
      tles = [{@iss_tle1, @iss_tle2}]

      epochs = [
        ~U[2024-03-15 12:00:00Z],
        ~U[2024-03-15 13:00:00Z]
      ]

      results =
        SatelliteArray.propagate_many_to_geodetic(tles, epochs,
          use_direct_nif: true,
          use_gpu_coords: true
        )

      # Should return 1 satellite x 2 epochs = 1 list of 2 results
      assert length(results) == 1
      assert [sat_results] = results
      assert length(sat_results) == 2

      # All results should be successful
      assert Enum.all?(
               sat_results,
               &match?({:ok, %{latitude: _, longitude: _, altitude_km: _}}, &1)
             )
    end
  end
end
