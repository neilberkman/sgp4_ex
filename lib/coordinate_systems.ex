defmodule Sgp4Ex.CoordinateSystems do
  @moduledoc """
  Coordinate system transformations for satellite positions.

  Provides conversions between:
  - TEME (True Equator Mean Equinox) - SGP4 output frame
  - ECEF (Earth-Centered Earth-Fixed) / ITRF
  - Geodetic (latitude, longitude, altitude) using WGS84
  """

  import :math, except: [floor: 1]
  import Nx.Defn

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
  - `opts` - Options (optional):
    - `:use_iau2000a` - Boolean, whether to use IAU 2000A nutation model (default: true for accuracy, false for speed)
    - `:use_gpu` - Boolean, whether to use GPU-optimized nutation (default: false)

  ## Returns
  `{:ok, %{latitude: lat, longitude: lon, altitude_km: alt}}` where:
  - `latitude` - Geodetic latitude in degrees (-90 to 90)
  - `longitude` - Geodetic longitude in degrees (-180 to 180)
  - `altitude_km` - Height above WGS84 ellipsoid in kilometers
  """
  @spec teme_to_geodetic({float, float, float}, DateTime.t(), keyword()) ::
          {:ok, %{latitude: float, longitude: float, altitude_km: float}}
  def teme_to_geodetic({x_teme, y_teme, z_teme}, datetime, opts \\ []) do
    # First convert TEME to ECEF
    {x_ecef, y_ecef, z_ecef} = teme_to_ecef({x_teme, y_teme, z_teme}, datetime, opts)

    # Then convert ECEF to Geodetic
    ecef_to_geodetic({x_ecef, y_ecef, z_ecef})
  end

  @doc """
  GPU-optimized batch conversion from TEME to ECEF using tensor operations.

  ## Parameters
  - `teme_positions` - Nx tensor of shape {n, 3} with TEME positions in km
  - `jd_ut1` - Julian Date in UT1
  - `jd_tt` - Julian Date in TT

  ## Returns
  Nx tensor of shape {n, 3} with ECEF positions in km
  """
  def teme_to_ecef_gpu_batch(teme_positions, jd_ut1, jd_tt) do
    # Get GAST as a tensor
    gast_hours_tensor =
      Sgp4Ex.IAU2000ANutationGPU.gast_gpu_tensor(
        Nx.tensor(jd_ut1, type: :f64),
        Nx.tensor(jd_tt, type: :f64),
        Nx.tensor(0.0, type: :f64),
        Nx.tensor(0.0, type: :f64)
      )

    # Convert to radians
    gast_rad_tensor = Sgp4Ex.IAU2000ANutationGPU.gast_to_radians_gpu(gast_hours_tensor)

    # Apply rotation in GPU
    Sgp4Ex.IAU2000ANutationGPU.rotate_teme_to_ecef_gpu(teme_positions, gast_rad_tensor)
  end

  @doc """
  Convert TEME coordinates to ECEF (Earth-Centered Earth-Fixed).

  Uses simplified conversion without polar motion corrections.
  Can optionally use IAU 2000A nutation model for higher precision.
  """
  @spec teme_to_ecef({float, float, float}, DateTime.t(), keyword()) :: {float, float, float}
  def teme_to_ecef({x_teme, y_teme, z_teme}, datetime, opts \\ []) do
    # Calculate sidereal time based on options
    # Default to IAU 2000A for accuracy (use_iau2000a: false for GMST if speed needed)
    sidereal_time_rad =
      if Keyword.get(opts, :use_iau2000a, true) do
        calculate_gast(datetime, opts)
      else
        calculate_gmst(datetime)
      end

    # Rotation matrix from TEME to ECEF (rotation about Z-axis)
    cos_st = cos(sidereal_time_rad)
    sin_st = sin(sidereal_time_rad)

    # Apply rotation
    x_ecef = cos_st * x_teme + sin_st * y_teme
    y_ecef = -sin_st * x_teme + cos_st * y_teme
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

  # Calculate Greenwich Apparent Sidereal Time (GAST) in radians
  # Uses IAU 2000A nutation model for high precision
  defp calculate_gast(datetime, opts) do
    # Convert to Julian Dates
    jd_ut1 = datetime_to_julian_date(datetime)
    # For simplicity, assume UT1 = UTC and TT = UTC + 69.184s
    jd_tt = jd_ut1 + 69.184 / 86400.0

    # Get GAST in hours from IAU 2000A module
    gast_hours =
      if Keyword.get(opts, :use_gpu, false) do
        Sgp4Ex.IAU2000ANutation.gast_gpu(jd_ut1, jd_tt)
      else
        Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
      end

    # Convert to radians
    gast_rad = gast_hours * 15.0 * pi() / 180.0
    rem_float(gast_rad, 2.0 * pi())
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

    # Add rotation for time of day (including microseconds)
    microseconds = elem(datetime.microsecond, 0)

    ut_hours =
      datetime.hour + datetime.minute / 60.0 + datetime.second / 3600.0 +
        microseconds / 3_600_000_000.0

    gmst = gmst0 + 360.98564724 * ut_hours / 24.0

    # Convert to radians and normalize to [0, 2π]
    gmst_rad = gmst * pi() / 180.0
    rem_float(gmst_rad, 2.0 * pi())
  end

  # Convert DateTime to Julian Date (Meeus algorithm, referenced to 0h UTC)
  @doc false
  def datetime_to_julian_date(datetime) do
    year = datetime.year
    month = datetime.month
    day = datetime.day

    # Handle January and February
    a = floor((14 - month) / 12)
    y = year + 4800 - a
    m = month + 12 * a - 3

    # Calculate Julian Day Number for 0h UTC (midnight)
    # The -32045.5 (not -32045) ensures we reference midnight, not noon
    jd_at_0h =
      day + floor((153 * m + 2) / 5) + 365 * y + floor(y / 4) -
        floor(y / 100) + floor(y / 400) - 32045.5

    # Calculate fraction of day since midnight
    microseconds = elem(datetime.microsecond, 0)

    fraction_from_midnight =
      datetime.hour / 24.0 +
        datetime.minute / 1440.0 +
        datetime.second / 86400.0 +
        microseconds / 86_400_000_000.0

    # Final Julian Date
    jd_at_0h + fraction_from_midnight
  end

  # Floating point remainder that handles negative numbers correctly
  defp rem_float(x, y) do
    result = x - y * floor(x / y)
    if result < 0, do: result + y, else: result
  end

  @doc """
  GPU-optimized batch conversion of TEME positions to geodetic coordinates.

  Processes multiple positions at once, keeping all calculations in GPU memory.
  This is much more efficient than converting positions one at a time.

  ## Parameters
  - `teme_positions` - List of {x, y, z} tuples in TEME frame (km)
  - `datetime` - UTC datetime for all positions

  ## Returns
  List of `{:ok, %{latitude: lat, longitude: lon, altitude_km: alt}}` tuples
  """
  def teme_to_geodetic_batch_gpu(teme_positions, datetime) when is_list(teme_positions) do
    # Convert to Julian Dates once for all positions
    jd_ut1 = datetime_to_julian_date(datetime)
    jd_tt = jd_ut1 + 69.184 / 86400.0

    # Get GAST using full GPU pipeline
    jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    fraction_ut1 = Nx.tensor(0.0, type: :f64)
    fraction_tt = Nx.tensor(0.0, type: :f64)

    # Calculate GAST in tensor form and convert to radians
    gast_hours_tensor =
      Sgp4Ex.IAU2000ANutationGPU.gast_gpu_tensor(
        jd_ut1_tensor,
        jd_tt_tensor,
        fraction_ut1,
        fraction_tt
      )

    gast_rad_tensor = Sgp4Ex.IAU2000ANutationGPU.gast_to_radians_gpu(gast_hours_tensor)

    # Extract scalar value for rotation matrix
    gast_rad = Nx.to_number(gast_rad_tensor)
    cos_st = cos(gast_rad)
    sin_st = sin(gast_rad)

    # Convert all positions
    Enum.map(teme_positions, fn {x_teme, y_teme, z_teme} ->
      # TEME to ECEF rotation
      x_ecef = cos_st * x_teme + sin_st * y_teme
      y_ecef = -sin_st * x_teme + cos_st * y_teme
      z_ecef = z_teme

      # ECEF to geodetic
      ecef_to_geodetic({x_ecef, y_ecef, z_ecef})
    end)
  end

  @doc """
  Full GPU pipeline for TEME to ECEF batch conversion.
  Returns ECEF positions as Nx tensor for further GPU processing.
  """
  def teme_to_ecef_batch_gpu_tensor(teme_positions_tensor, datetime) do
    # Convert to Julian Dates
    jd_ut1 = datetime_to_julian_date(datetime)
    jd_tt = jd_ut1 + 69.184 / 86400.0

    # Get GAST using full GPU pipeline
    jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    fraction_ut1 = Nx.tensor(0.0, type: :f64)
    fraction_tt = Nx.tensor(0.0, type: :f64)

    # Calculate GAST and convert to radians
    gast_hours_tensor =
      Sgp4Ex.IAU2000ANutationGPU.gast_gpu_tensor(
        jd_ut1_tensor,
        jd_tt_tensor,
        fraction_ut1,
        fraction_tt
      )

    gast_rad_tensor = Sgp4Ex.IAU2000ANutationGPU.gast_to_radians_gpu(gast_hours_tensor)

    # Perform batch rotation in GPU
    rotate_teme_to_ecef_gpu(teme_positions_tensor, gast_rad_tensor)
  end

  # GPU kernel for batch TEME to ECEF rotation
  defnp rotate_teme_to_ecef_gpu(teme_positions, gast_rad) do
    cos_st = Nx.cos(gast_rad)
    sin_st = Nx.sin(gast_rad)

    # Extract x, y, z components
    x_teme = teme_positions[[.., 0]]
    y_teme = teme_positions[[.., 1]]
    z_teme = teme_positions[[.., 2]]

    # Apply rotation
    x_ecef = cos_st * x_teme + sin_st * y_teme
    y_ecef = -sin_st * x_teme + cos_st * y_teme
    z_ecef = z_teme

    # Stack back into position matrix
    Nx.stack([x_ecef, y_ecef, z_ecef], axis: 1)
  end
end
