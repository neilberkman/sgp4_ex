defmodule Sgp4Ex.CoordinateSystems do
  @moduledoc """
  Coordinate system transformations for satellite positions.

  Provides conversions between:
  - TEME (True Equator Mean Equinox) - SGP4 output frame
  - ECEF (Earth-Centered Earth-Fixed) / ITRF
  - Geodetic (latitude, longitude, altitude) using WGS84
  """

  import :math, except: [floor: 1]

  # WGS84 ellipsoid parameters
  # Equatorial radius in km
  @wgs84_a 6378.137
  # Flattening
  @wgs84_f 1.0 / 298.257223563
  # First eccentricity squared
  @wgs84_e2 2.0 * @wgs84_f - @wgs84_f * @wgs84_f

  @doc """
  Convert TEME position to geodetic coordinates (latitude, longitude, altitude).

  This is the main convenience function that chains TEME → ECEF → Geodetic conversions.

  ## Parameters
  - `teme_position` - Position in TEME frame {x, y, z} in km
  - `datetime` - UTC datetime for the position

  ## Returns
  `{:ok, %{latitude: lat, longitude: lon, altitude_km: alt}}` where:
  - `latitude` - Geodetic latitude in degrees (-90 to 90)
  - `longitude` - Geodetic longitude in degrees (-180 to 180)
  - `altitude_km` - Height above WGS84 ellipsoid in kilometers
  """
  @spec teme_to_geodetic({float, float, float}, DateTime.t()) ::
          {:ok, %{latitude: float, longitude: float, altitude_km: float}}
  def teme_to_geodetic({x_teme, y_teme, z_teme}, datetime) do
    # Step 1: TEME to ECEF
    {x_ecef, y_ecef, z_ecef} = teme_to_ecef({x_teme, y_teme, z_teme}, datetime)

    # Step 2: ECEF to Geodetic
    ecef_to_geodetic({x_ecef, y_ecef, z_ecef})
  end

  @doc """
  Convert TEME coordinates to ECEF (Earth-Centered Earth-Fixed).

  Uses simplified conversion without polar motion corrections.
  """
  @spec teme_to_ecef({float, float, float}, DateTime.t()) :: {float, float, float}
  def teme_to_ecef({x_teme, y_teme, z_teme}, datetime) do
    # Calculate Greenwich Mean Sidereal Time
    gmst_rad = calculate_gmst(datetime)

    # Rotation matrix from TEME to ECEF (rotation about Z-axis by -GMST)
    cos_gmst = cos(gmst_rad)
    sin_gmst = sin(gmst_rad)

    # Apply rotation
    x_ecef = cos_gmst * x_teme + sin_gmst * y_teme
    y_ecef = -sin_gmst * x_teme + cos_gmst * y_teme
    z_ecef = z_teme

    {x_ecef, y_ecef, z_ecef}
  end

  @doc """
  Convert ECEF Cartesian coordinates to geodetic (lat/lon/alt).

  Uses iterative algorithm to account for Earth's ellipsoid shape.
  Based on Vallado's algorithm.
  """
  @spec ecef_to_geodetic({float, float, float}) ::
          {:ok, %{latitude: float, longitude: float, altitude_km: float}}
  def ecef_to_geodetic({x, y, z}) do
    # Calculate longitude (straightforward)
    lon_rad = atan2(y, x)

    # For latitude and altitude, use iterative method
    r = sqrt(x * x + y * y)

    # Initial guess for latitude
    lat_rad = atan2(z, r)

    # Iterate to refine latitude (typically converges in 3 iterations)
    lat_rad =
      Enum.reduce(1..3, lat_rad, fn _, lat ->
        sin_lat = sin(lat)
        cos_lat = cos(lat)
        n = @wgs84_a / sqrt(1.0 - @wgs84_e2 * sin_lat * sin_lat)

        # Avoid division by zero at poles
        if abs(cos_lat) < 1.0e-10 do
          lat
        else
          h = r / cos_lat - n
          atan2(z, r * (1.0 - @wgs84_e2 * n / (n + h)))
        end
      end)

    # Calculate altitude
    sin_lat = sin(lat_rad)
    n = @wgs84_a / sqrt(1.0 - @wgs84_e2 * sin_lat * sin_lat)

    # 45 degrees
    altitude_km =
      if abs(lat_rad) < 0.785398 do
        # Near equator, use horizontal distance
        r / cos(lat_rad) - n
      else
        # Near poles, use vertical distance
        z / sin_lat - n * (1.0 - @wgs84_e2)
      end

    # Convert to degrees
    lat_deg = lat_rad * 180.0 / pi()
    lon_deg = lon_rad * 180.0 / pi()

    {:ok,
     %{
       latitude: lat_deg,
       longitude: lon_deg,
       altitude_km: altitude_km
     }}
  end

  # Calculate Greenwich Mean Sidereal Time (GMST) in radians
  # Simplified version using linear approximation
  defp calculate_gmst(datetime) do
    # Convert to Julian Date
    jd = datetime_to_julian_date(datetime)

    # Calculate centuries since J2000
    t = (jd - 2_451_545.0) / 36_525.0

    # GMST at 0h UT1 (in degrees)
    gmst0 = 100.46061837 + 36_000.770053608 * t + 0.000387933 * t * t

    # Add rotation for time of day
    ut_hours = datetime.hour + datetime.minute / 60.0 + datetime.second / 3600.0
    gmst = gmst0 + 360.98564724 * ut_hours / 24.0

    # Convert to radians and normalize to [0, 2π]
    gmst_rad = gmst * pi() / 180.0
    rem_float(gmst_rad, 2.0 * pi())
  end

  # Convert DateTime to Julian Date
  defp datetime_to_julian_date(datetime) do
    {year, month, day} = {datetime.year, datetime.month, datetime.day}

    # Handle January and February
    {year, month} =
      if month <= 2 do
        {year - 1, month + 12}
      else
        {year, month}
      end

    a = div(year, 100)
    b = 2 - a + div(a, 4)

    jd = floor(365.25 * (year + 4716)) + floor(30.6001 * (month + 1)) + day + b - 1524.5

    # Add fractional day
    fractional_day = (datetime.hour + datetime.minute / 60.0 + datetime.second / 3600.0) / 24.0

    jd + fractional_day
  end

  # Floating point remainder that handles negative numbers correctly
  defp rem_float(x, y) do
    result = x - y * floor(x / y)
    if result < 0, do: result + y, else: result
  end
end
