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
  - `opts` - Options (optional)
    - `:use_gmst` - Use GMST instead of GMAT (default: false)

  ## Returns
  `{:ok, %{latitude: lat, longitude: lon, altitude_km: alt}}` where:
  - `latitude` - Geodetic latitude in degrees (-90 to 90)
  - `longitude` - Geodetic longitude in degrees (-180 to 180)
  - `altitude_km` - Height above WGS84 ellipsoid in kilometers
  """
  @spec teme_to_geodetic(Sgp4Ex.TemeState.t(), DateTime.t(), keyword()) ::
          {:ok, %{latitude: float, longitude: float, altitude_km: float}}
  def teme_to_geodetic(%Sgp4Ex.TemeState{} = teme_state, datetime, opts \\ []) do
    # Step 1: TEME to ECEF
    {x_ecef, y_ecef, z_ecef} = teme_to_ecef(teme_state, datetime, opts)

    # Step 2: ECEF to Geodetic
    ecef_to_geodetic({x_ecef, y_ecef, z_ecef})
  end

  @doc """
  Convert TEME coordinates to ECEF (Earth-Centered Earth-Fixed).

  By default uses GMAT (Greenwich Apparent Sidereal Time) which includes
  nutation corrections for higher accuracy. Set use_gmst: true in opts
  to use the simpler GMST (Greenwich Mean Sidereal Time) without nutation.

  ## Options
  - `:use_gmst` - Use GMST instead of GMAT (default: false)
  """
  @spec teme_to_ecef(Sgp4Ex.TemeState.t(), DateTime.t(), keyword()) :: {float, float, float}
  def teme_to_ecef(
        %Sgp4Ex.TemeState{
          position: {x_teme, y_teme, z_teme},
          velocity: {vx_teme, vy_teme, vz_teme}
        },
        datetime,
        opts \\ []
      ) do
    # Convert positions from km to meters for NIF
    x_m = x_teme * 1000.0
    y_m = y_teme * 1000.0
    z_m = z_teme * 1000.0
    vx_ms = vx_teme * 1000.0
    vy_ms = vy_teme * 1000.0
    vz_ms = vz_teme * 1000.0

    # Convert DateTime to tuple format for NIF
    datetime_tuple = datetime_to_tuple(datetime)

    # Use GMAT by default (matches Skyfield), or GMST if specified
    {{x_ecef_m, y_ecef_m, z_ecef_m}, _} =
      if Keyword.get(opts, :use_gmst, false) do
        SGP4NIF.teme_to_ecef_gmst(x_m, y_m, z_m, vx_ms, vy_ms, vz_ms, datetime_tuple)
      else
        SGP4NIF.teme_to_ecef_gmat(x_m, y_m, z_m, vx_ms, vy_ms, vz_ms, datetime_tuple)
      end

    # Convert back to km
    {x_ecef_m / 1000.0, y_ecef_m / 1000.0, z_ecef_m / 1000.0}
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

  # Convert DateTime to tuple format for NIF
  defp datetime_to_tuple(datetime) do
    microseconds = elem(datetime.microsecond, 0)

    {{datetime.year, datetime.month, datetime.day},
     {datetime.hour, datetime.minute, datetime.second, microseconds}}
  end
end
