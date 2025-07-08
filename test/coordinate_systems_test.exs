defmodule Sgp4Ex.CoordinateSystemsTest do
  use ExUnit.Case
  alias Sgp4Ex.CoordinateSystems

  describe "ecef_to_geodetic/1" do
    test "converts equatorial position correctly" do
      # Position on equator at prime meridian
      # On equator at 0° longitude
      ecef = {6378.137, 0.0, 0.0}

      assert {:ok, result} = CoordinateSystems.ecef_to_geodetic(ecef)
      assert_in_delta result.latitude, 0.0, 0.001
      assert_in_delta result.longitude, 0.0, 0.001
      assert_in_delta result.altitude_km, 0.0, 0.001
    end

    test "converts position at 90° longitude" do
      # Position on equator at 90° E
      ecef = {0.0, 6378.137, 0.0}

      assert {:ok, result} = CoordinateSystems.ecef_to_geodetic(ecef)
      assert_in_delta result.latitude, 0.0, 0.001
      assert_in_delta result.longitude, 90.0, 0.001
      assert_in_delta result.altitude_km, 0.0, 0.001
    end

    test "converts north pole position" do
      # Position at north pole
      # Approximate polar radius
      ecef = {0.0, 0.0, 6356.752}

      assert {:ok, result} = CoordinateSystems.ecef_to_geodetic(ecef)
      assert_in_delta result.latitude, 90.0, 0.001
      # Longitude is undefined at poles, but should be a valid number
      assert is_float(result.longitude)
      # Within 1 km
      assert_in_delta result.altitude_km, 0.0, 1.0
    end

    test "converts position with altitude" do
      # Position above equator at prime meridian (ISS altitude ~400km)
      # 400km above equator
      ecef = {6778.137, 0.0, 0.0}

      assert {:ok, result} = CoordinateSystems.ecef_to_geodetic(ecef)
      assert_in_delta result.latitude, 0.0, 0.001
      assert_in_delta result.longitude, 0.0, 0.001
      assert_in_delta result.altitude_km, 400.0, 0.1
    end

    test "handles negative longitudes correctly" do
      # Position at 90° W
      ecef = {0.0, -6378.137, 0.0}

      assert {:ok, result} = CoordinateSystems.ecef_to_geodetic(ecef)
      assert_in_delta result.latitude, 0.0, 0.001
      assert_in_delta result.longitude, -90.0, 0.001
      assert_in_delta result.altitude_km, 0.0, 0.001
    end
  end

  describe "teme_to_ecef/2" do
    test "applies Earth rotation correctly" do
      # Test at J2000 epoch when GMST should be near 0
      datetime = ~U[2000-01-01 12:00:00Z]
      teme = {6378.137, 0.0, 0.0}

      {x, y, z} = CoordinateSystems.teme_to_ecef(teme, datetime)

      # Should rotate by GMST angle
      assert is_float(x)
      assert is_float(y)
      assert is_float(z)
      # Z should be unchanged by rotation about Z axis
      assert_in_delta z, 0.0, 0.001
    end

    test "preserves position magnitude" do
      datetime = ~U[2021-10-02 14:00:00Z]
      teme = {4000.0, 3000.0, 2000.0}

      {x_ecef, y_ecef, z_ecef} = CoordinateSystems.teme_to_ecef(teme, datetime)

      # Calculate magnitudes
      teme_mag = :math.sqrt(4000.0 * 4000.0 + 3000.0 * 3000.0 + 2000.0 * 2000.0)
      ecef_mag = :math.sqrt(x_ecef * x_ecef + y_ecef * y_ecef + z_ecef * z_ecef)

      # Rotation should preserve magnitude
      assert_in_delta teme_mag, ecef_mag, 0.001
    end
  end

  describe "teme_to_geodetic/2" do
    test "converts ISS-like position" do
      # Approximate ISS position in TEME
      datetime = ~U[2021-10-02 14:00:00Z]
      # km
      teme = {-3918.875, 5183.641, 1983.254}

      assert {:ok, result} = CoordinateSystems.teme_to_geodetic(teme, datetime)

      # Should be reasonable values for ISS
      # ISS inclination
      assert result.latitude >= -52 and result.latitude <= 52
      assert result.longitude >= -180 and result.longitude <= 180
      # ISS altitude range
      assert result.altitude_km >= 400 and result.altitude_km <= 450
    end

    test "handles subsatellite point calculation" do
      # Position directly above equator
      datetime = ~U[2021-01-01 00:00:00Z]
      # At altitude of 35786 km (approximate GEO)
      teme = {42164.0, 0.0, 0.0}

      assert {:ok, result} = CoordinateSystems.teme_to_geodetic(teme, datetime)

      # Should be near equator
      assert_in_delta result.latitude, 0.0, 1.0
      assert is_float(result.longitude)
      # GEO altitude
      assert_in_delta result.altitude_km, 35786.0, 100.0
    end
  end
end
