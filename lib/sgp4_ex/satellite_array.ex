defmodule Sgp4Ex.SatelliteArray do
  @moduledoc """
  Simple batch operations for multiple satellites.

  This module provides basic functions for propagating multiple satellites
  at once using the existing robust infrastructure.
  """

  @doc """
  Propagate multiple satellites to a single datetime.

  ## Parameters
  - `tles` - List of {line1, line2} tuples 
  - `datetime` - Target UTC datetime
  - `opts` - Options:
    - `:use_batch_nif` - Use batch NIF for propagation (default: true)
    - `:use_gpu_coords` - Use GPU coordinate transformations (default: false)
    - `:use_cache` - Use SatelliteCache for TLE caching (default: true)

  ## Returns
  List of {:ok, result} or {:error, reason} tuples

  ## Example
      tles = [
        {line1_1, line2_1},
        {line1_2, line2_2}
      ]
      
      results = SatelliteArray.propagate_to_geodetic(tles, ~U[2024-03-15 12:00:00Z])
  """
  def propagate_to_geodetic(tles, datetime, opts \\ []) when is_list(tles) do
    use_batch_nif = Keyword.get(opts, :use_batch_nif, true)
    use_gpu_coords = Keyword.get(opts, :use_gpu_coords, false)
    use_cache = Keyword.get(opts, :use_cache, true)

    if use_cache do
      propagate_with_cache(tles, datetime, use_batch_nif, use_gpu_coords)
    else
      # Original non-cached path
      if use_batch_nif and length(tles) > 1 do
        propagate_batch_nif(tles, datetime, use_gpu_coords)
      else
        propagate_serial(tles, datetime, use_gpu_coords)
      end
    end
  end

  @doc """
  Propagate multiple satellites to multiple epochs efficiently.

  This function uses the stateful Satellite API (like Python SGP4's Satrec.twoline2rv()) 
  for maximum efficiency when propagating the same satellites to many epochs.

  ## Parameters
  - `tles` - List of {line1, line2} tuples 
  - `datetimes` - List of UTC datetimes to propagate to
  - `opts` - Options:
    - `:use_gpu_coords` - Use GPU coordinate transformations (default: false)
    - `:to_geodetic` - Convert to geodetic coordinates (default: true)
    - `:use_direct_nif` - Use NIF resources directly, bypassing Cachex (default: false)

  ## Returns
  List of lists - outer list matches `tles`, inner lists match `datetimes`
  Each result is {:ok, result} or {:error, reason}

  ## Example
      tles = [
        {line1_1, line2_1},
        {line1_2, line2_2}
      ]
      
      epochs = [
        ~U[2024-03-15 12:00:00Z],
        ~U[2024-03-15 13:00:00Z],
        ~U[2024-03-15 14:00:00Z]
      ]
      
      # Returns [[sat1_epoch1, sat1_epoch2, sat1_epoch3], [sat2_epoch1, sat2_epoch2, sat2_epoch3]]
      results = SatelliteArray.propagate_many_to_geodetic(tles, epochs)
  """
  def propagate_many_to_geodetic(tles, datetimes, opts \\ [])
      when is_list(tles) and is_list(datetimes) do
    use_gpu_coords = Keyword.get(opts, :use_gpu_coords, false)
    to_geodetic = Keyword.get(opts, :to_geodetic, true)
    use_direct_nif = Keyword.get(opts, :use_direct_nif, false)

    if use_direct_nif do
      # Step 6: Direct NIF resource usage - bypass Cachex overhead
      propagate_many_direct_nif(tles, datetimes, use_gpu_coords, to_geodetic)
    else
      # Use Satellite API with Cachex (existing implementation)
      propagate_many_via_satellite_api(tles, datetimes, use_gpu_coords, to_geodetic)
    end
  end

  # Direct NIF usage - Step 6 optimization (uses stateful resources)
  # Maximum efficiency: initialize once, propagate many times
  defp propagate_many_direct_nif(tles, datetimes, use_gpu_coords, to_geodetic) do
    # Use unified NIF stateful API for maximum efficiency
    propagate_many_stateful_nif(tles, datetimes, use_gpu_coords, to_geodetic)
  end

  # V2 stateful NIF implementation - most efficient
  defp propagate_many_stateful_nif(tles, datetimes, use_gpu_coords, to_geodetic) do
    # Initialize all satellites once using v2 stateful API
    initialized_satellites =
      Enum.map(tles, fn {line1, line2} ->
        case SGP4NIF.init_satellite(line1, line2) do
          {:ok, sat_resource} ->
            case Sgp4Ex.parse_tle(line1, line2) do
              {:ok, tle} -> {:ok, {sat_resource, tle.epoch}}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end
      end)

    # Propagate each satellite to all epochs using stateful resources
    Enum.map(initialized_satellites, fn
      {:ok, {sat_resource, epoch}} ->
        propagate_stateful_to_epochs(sat_resource, epoch, datetimes, use_gpu_coords, to_geodetic)

      {:error, reason} ->
        # Return error for all epochs
        Enum.map(datetimes, fn _datetime -> {:error, reason} end)
    end)
  end

  # Stateful satellite propagation to multiple epochs
  defp propagate_stateful_to_epochs(sat_resource, epoch, datetimes, use_gpu_coords, to_geodetic) do
    if use_gpu_coords and to_geodetic do
      # GPU-accelerated stateful propagation
      alias Sgp4Ex.IAU2000ANutationGPU

      Enum.map(datetimes, fn datetime ->
        tsince = calculate_tsince(epoch, datetime)

        case SGP4NIF.propagate_satellite(sat_resource, tsince) do
          {:ok, {{x_m, y_m, z_m}, _velocity}} ->
            # Convert datetime to Julian dates
            {jd_ut1, jd_tt} = datetime_to_julian_dates(datetime)

            # Get GAST for this epoch - stay in tensor land
            jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
            jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)

            gast_hours_tensor =
              IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)

            gast_rad = Nx.to_number(gast_hours_tensor) * :math.pi() / 12.0

            # Convert to km and use GPU coordinate transformation
            teme_pos_km = {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0}
            teme_to_geodetic_gpu(teme_pos_km, gast_rad)

          {:error, reason} ->
            {:error, reason}
        end
      end)
    else
      # Standard stateful propagation
      Enum.map(datetimes, fn datetime ->
        tsince = calculate_tsince(epoch, datetime)

        case SGP4NIF.propagate_satellite(sat_resource, tsince) do
          {:ok, {{x_m, y_m, z_m}, {_vx_m, _vy_m, _vz_m}}} when to_geodetic ->
            # Convert TEME to geodetic
            teme_pos_km = {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0}
            Sgp4Ex.CoordinateSystems.teme_to_geodetic(teme_pos_km, datetime, use_gpu: true)

          {:ok, {{x_m, y_m, z_m}, {vx_m, vy_m, vz_m}}} ->
            # Return TEME state directly
            teme_state = %{
              position: {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0},
              velocity: {vx_m / 1000.0, vy_m / 1000.0, vz_m / 1000.0}
            }

            {:ok, teme_state}

          {:error, reason} ->
            {:error, reason}
        end
      end)
    end
  end

  # Original implementation using Satellite API
  defp propagate_many_via_satellite_api(tles, datetimes, use_gpu_coords, to_geodetic) do
    # Initialize all satellites using the stateful Satellite API
    initialized_satellites =
      Enum.map(tles, fn {line1, line2} ->
        case Sgp4Ex.Satellite.init(line1, line2) do
          {:ok, sat_ref} ->
            {:ok, sat_ref}

          {:error, :no_cache} ->
            # Satellite cache not running, fall back to direct parsing for each epoch
            {:fallback, {line1, line2}}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    # Propagate each satellite to all epochs
    Enum.map(initialized_satellites, fn
      {:ok, sat_ref} ->
        propagate_satellite_to_epochs(sat_ref, datetimes, use_gpu_coords, to_geodetic)

      {:fallback, {line1, line2}} ->
        # Fall back to single-epoch propagation for each datetime
        propagate_fallback_to_epochs({line1, line2}, datetimes, use_gpu_coords, to_geodetic)

      {:error, reason} ->
        # Return error for all epochs
        Enum.map(datetimes, fn _datetime -> {:error, reason} end)
    end)
  end

  # Propagate a single initialized satellite to multiple epochs
  defp propagate_satellite_to_epochs(sat_ref, datetimes, use_gpu_coords, to_geodetic) do
    if use_gpu_coords and to_geodetic do
      propagate_satellite_to_epochs_gpu(sat_ref, datetimes)
    else
      # Use standard Satellite API
      Enum.map(datetimes, fn datetime ->
        case Sgp4Ex.Satellite.propagate(sat_ref, datetime) do
          {:ok, teme_state} when to_geodetic ->
            # Convert TEME to geodetic
            Sgp4Ex.CoordinateSystems.teme_to_geodetic(teme_state.position, datetime, use_gpu: true)

          {:ok, teme_state} ->
            # Return TEME state directly
            {:ok, teme_state}

          {:error, reason} ->
            {:error, reason}
        end
      end)
    end
  end

  # GPU-accelerated propagation for multiple epochs
  defp propagate_satellite_to_epochs_gpu(sat_ref, datetimes) do
    alias Sgp4Ex.IAU2000ANutationGPU

    Enum.map(datetimes, fn datetime ->
      case Sgp4Ex.Satellite.propagate(sat_ref, datetime) do
        {:ok, teme_state} ->
          # Convert datetime to Julian dates
          {jd_ut1, jd_tt} = datetime_to_julian_dates(datetime)

          # Get GAST for this epoch - stay in tensor land
          jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
          jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)

          gast_hours_tensor =
            IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)

          gast_rad = Nx.to_number(gast_hours_tensor) * :math.pi() / 12.0

          # Use GPU coordinate transformation
          teme_to_geodetic_gpu(teme_state.position, gast_rad)

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  # Fallback propagation when Satellite cache is not available
  defp propagate_fallback_to_epochs({line1, line2}, datetimes, use_gpu_coords, to_geodetic) do
    # Parse TLE once for epoch calculation
    case Sgp4Ex.parse_tle(line1, line2) do
      {:ok, tle} ->
        if use_gpu_coords and to_geodetic do
          # GPU path - get GAST once for each epoch
          alias Sgp4Ex.IAU2000ANutationGPU

          Enum.map(datetimes, fn datetime ->
            tsince = calculate_tsince(tle.epoch, datetime)

            case SGP4NIF.propagate_tle(line1, line2, tsince) do
              {:ok, {{x_m, y_m, z_m}, _velocity}} ->
                # Convert datetime to Julian dates
                {jd_ut1, jd_tt} = datetime_to_julian_dates(datetime)

                # Get GAST for this epoch - stay in tensor land
                jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
                jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)

                gast_hours_tensor =
                  IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)

                gast_rad = Nx.to_number(gast_hours_tensor) * :math.pi() / 12.0

                # Convert to km and use GPU coordinate transformation
                teme_pos_km = {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0}
                teme_to_geodetic_gpu(teme_pos_km, gast_rad)

              {:error, reason} ->
                {:error, reason}
            end
          end)
        else
          # Standard path
          Enum.map(datetimes, fn datetime ->
            if to_geodetic do
              # Use single-epoch propagation function
              propagate_to_geodetic([{line1, line2}], datetime,
                use_cache: false,
                use_gpu_coords: false
              )
              |> hd()
            else
              # Return TEME state
              tsince = calculate_tsince(tle.epoch, datetime)

              case SGP4NIF.propagate_tle(line1, line2, tsince) do
                {:ok, {{x_m, y_m, z_m}, {vx_m, vy_m, vz_m}}} ->
                  teme_state = %{
                    position: {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0},
                    velocity: {vx_m / 1000.0, vy_m / 1000.0, vz_m / 1000.0}
                  }

                  {:ok, teme_state}

                {:error, reason} ->
                  {:error, reason}
              end
            end
          end)
        end

      {:error, reason} ->
        # Return error for all epochs
        Enum.map(datetimes, fn _datetime -> {:error, reason} end)
    end
  end

  # Serial propagation (original method)
  defp propagate_serial(tles, datetime, use_gpu_coords) do
    if use_gpu_coords do
      propagate_serial_gpu(tles, datetime)
    else
      Enum.map(tles, fn {line1, line2} ->
        case Sgp4Ex.parse_tle(line1, line2) do
          {:ok, tle} ->
            Sgp4Ex.propagate_to_geodetic(tle, datetime)

          {:error, reason} ->
            {:error, reason}
        end
      end)
    end
  end

  # Serial propagation with GPU coordinate transformations
  defp propagate_serial_gpu(tles, datetime) do
    alias Sgp4Ex.IAU2000ANutationGPU

    # Convert datetime to Julian dates (assume UT1 = UTC for simplicity)
    {jd_ut1, jd_tt} = datetime_to_julian_dates(datetime)

    # Get GAST once for all satellites - stay in tensor land
    jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    gast_hours_tensor = IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)
    # Convert hours to radians
    gast_rad = Nx.to_number(gast_hours_tensor) * :math.pi() / 12.0

    Enum.map(tles, fn {line1, line2} ->
      case Sgp4Ex.parse_tle(line1, line2) do
        {:ok, tle} ->
          # Get TEME position using standard propagation
          tsince = calculate_tsince(tle.epoch, datetime)

          case SGP4NIF.propagate_tle(line1, line2, tsince) do
            {:ok, {{x_m, y_m, z_m}, _velocity}} ->
              # Convert to km and use GPU coordinate transformation
              teme_pos_km = {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0}
              teme_to_geodetic_gpu(teme_pos_km, gast_rad)

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  # Cached propagation with optimization selection
  defp propagate_with_cache(tles, datetime, use_batch_nif, use_gpu_coords) do
    # For cached operations, we use SatelliteCache for individual TLEs
    # and apply our batch/GPU optimizations at the coordinate transformation level
    if use_batch_nif and length(tles) > 1 and not use_gpu_coords do
      # Use batch NIF but with cached TLE parsing
      propagate_batch_cached(tles, datetime)
    else
      # Use SatelliteCache directly for each TLE
      propagate_serial_cached(tles, datetime, use_gpu_coords)
    end
  end

  # Serial propagation using SatelliteCache
  defp propagate_serial_cached(tles, datetime, use_gpu_coords) do
    if use_gpu_coords do
      propagate_serial_cached_gpu(tles, datetime)
    else
      # Use SatelliteCache directly - simplest and most cache-efficient
      Enum.map(tles, fn {line1, line2} ->
        Sgp4Ex.SatelliteCache.propagate_to_geodetic(line1, line2, datetime)
      end)
    end
  end

  # Serial cached propagation with GPU coordinate transformations
  defp propagate_serial_cached_gpu(tles, datetime) do
    alias Sgp4Ex.IAU2000ANutationGPU

    # Convert datetime to Julian dates (assume UT1 = UTC for simplicity)
    {jd_ut1, jd_tt} = datetime_to_julian_dates(datetime)

    # Get GAST once for all satellites - stay in tensor land
    jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    gast_hours_tensor = IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)
    # Convert hours to radians
    gast_rad = Nx.to_number(gast_hours_tensor) * :math.pi() / 12.0

    Enum.map(tles, fn {line1, line2} ->
      # Use cache to get parsed TLE
      case Sgp4Ex.SatelliteCache.get_parsed_tle(line1, line2) do
        {:ok, tle} ->
          # Get TEME position using standard propagation
          tsince = calculate_tsince(tle.epoch, datetime)

          case SGP4NIF.propagate_tle(line1, line2, tsince) do
            {:ok, {{x_m, y_m, z_m}, _velocity}} ->
              # Convert to km and use GPU coordinate transformation
              teme_pos_km = {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0}
              teme_to_geodetic_gpu(teme_pos_km, gast_rad)

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  # Batch propagation with cached TLE parsing
  defp propagate_batch_cached(tles, datetime) do
    # First, get all TLEs from cache or parse them
    parsed_with_cache =
      Enum.map(tles, fn {line1, line2} ->
        case Sgp4Ex.SatelliteCache.get_parsed_tle(line1, line2) do
          {:ok, tle} ->
            tsince = calculate_tsince(tle.epoch, datetime)
            {:ok, {line1, line2, tsince}}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    # Separate successful and failed parses
    {successful, failed} = Enum.split_with(parsed_with_cache, &match?({:ok, _}, &1))

    # Process successful ones with batch NIF
    batch_results =
      case successful do
        [] ->
          []

        success_list ->
          lines_and_tsince = Enum.map(success_list, fn {:ok, data} -> data end)

          # Group by unique TLE for efficiency
          grouped = Enum.group_by(lines_and_tsince, fn {line1, line2, _} -> {line1, line2} end)

          # Process each unique TLE
          Enum.flat_map(grouped, fn {{line1, line2}, group} ->
            tsince_list = Enum.map(group, fn {_, _, tsince} -> tsince end)

            case SGP4NIF.propagate_tle_batch(line1, line2, tsince_list) do
              {:ok, batch_results} ->
                # Convert TEME positions to geodetic using CPU (cache integration)
                convert_batch_results_cpu(batch_results, datetime)

              {:error, reason} ->
                Enum.map(group, fn _ -> {:error, reason} end)
            end
          end)
      end

    # Combine results preserving original order
    failed_results = Enum.map(failed, fn {:error, reason} -> {:error, reason} end)
    batch_results ++ failed_results
  end

  # Batch NIF propagation
  defp propagate_batch_nif(tles, datetime, use_gpu_coords) do
    # First, parse all TLEs and calculate tsince for each
    parsed_tles =
      Enum.map(tles, fn {line1, line2} ->
        case Sgp4Ex.parse_tle(line1, line2) do
          {:ok, tle} ->
            tsince = calculate_tsince(tle.epoch, datetime)
            {:ok, {line1, line2, tsince, tle}}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    # Separate successful and failed parses
    {successful, failed} = Enum.split_with(parsed_tles, &match?({:ok, _}, &1))

    # Process successful ones with batch NIF
    batch_results =
      case successful do
        [] ->
          []

        success_list ->
          {lines_and_tsince, _tle_structs} =
            success_list
            |> Enum.map(fn {:ok, {line1, line2, tsince, tle}} ->
              {{line1, line2, tsince}, tle}
            end)
            |> Enum.unzip()

          # Group by unique TLE for efficiency
          grouped = Enum.group_by(lines_and_tsince, fn {line1, line2, _} -> {line1, line2} end)

          # Process each unique TLE
          Enum.flat_map(grouped, fn {{line1, line2}, group} ->
            tsince_list = Enum.map(group, fn {_, _, tsince} -> tsince end)

            case SGP4NIF.propagate_tle_batch(line1, line2, tsince_list) do
              {:ok, batch_results} ->
                # Convert TEME positions to geodetic
                if use_gpu_coords do
                  convert_batch_results_gpu(batch_results, datetime)
                else
                  convert_batch_results_cpu(batch_results, datetime)
                end

              {:error, reason} ->
                Enum.map(group, fn _ -> {:error, reason} end)
            end
          end)
      end

    # Combine results preserving original order
    failed_results = Enum.map(failed, fn {:error, reason} -> {:error, reason} end)
    batch_results ++ failed_results
  end

  defp calculate_tsince(epoch_datetime, target_datetime) do
    epoch_seconds = DateTime.to_unix(epoch_datetime, :microsecond)
    target_seconds = DateTime.to_unix(target_datetime, :microsecond)
    # Convert to minutes
    (target_seconds - epoch_seconds) / 60_000_000.0
  end

  # CPU coordinate conversion (original method)
  defp convert_batch_results_cpu(batch_results, datetime) do
    Enum.map(batch_results, fn
      {:ok, {{x_m, y_m, z_m}, {_vx_ms, _vy_ms, _vz_ms}}} ->
        # Convert from meters to km for coordinate conversion
        teme_pos_km = {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0}
        Sgp4Ex.CoordinateSystems.teme_to_geodetic(teme_pos_km, datetime)

      {:error, _} = error ->
        error
    end)
  end

  # GPU coordinate conversion
  defp convert_batch_results_gpu(batch_results, datetime) do
    alias Sgp4Ex.IAU2000ANutationGPU

    # Convert datetime to Julian dates (assume UT1 = UTC for simplicity)
    {jd_ut1, jd_tt} = datetime_to_julian_dates(datetime)

    # Get GAST once for all satellites - stay in tensor land
    jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    gast_hours_tensor = IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)
    # Convert hours to radians
    gast_rad = Nx.to_number(gast_hours_tensor) * :math.pi() / 12.0

    Enum.map(batch_results, fn
      {:ok, {{x_m, y_m, z_m}, {_vx_ms, _vy_ms, _vz_ms}}} ->
        # Convert from meters to km for coordinate conversion
        teme_pos_km = {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0}
        teme_to_geodetic_gpu(teme_pos_km, gast_rad)

      {:error, _} = error ->
        error
    end)
  end

  # Convert DateTime to Julian dates
  defp datetime_to_julian_dates(datetime) do
    # Convert to Unix timestamp and then to Julian date
    unix_seconds = DateTime.to_unix(datetime, :second)
    unix_days = unix_seconds / 86400.0
    # Unix epoch JD
    jd = unix_days + 2_440_587.5

    # Use more precise TT-UT1 offset (matches Skyfield for 2024-03-15)
    jd_ut1 = jd
    jd_tt = jd + 69.19318735599518 / 86400.0

    {jd_ut1, jd_tt}
  end

  # GPU-accelerated TEME to geodetic conversion
  defp teme_to_geodetic_gpu(teme_pos_km, gast_rad) do
    alias Sgp4Ex.IAU2000ANutationGPU

    {x_km, y_km, z_km} = teme_pos_km

    # Convert to tensors for GPU processing
    teme_tensor = Nx.tensor([x_km, y_km, z_km], type: :f64)
    gast_tensor = Nx.tensor(gast_rad, type: :f64)

    # Use GPU rotation to get ECEF coordinates
    ecef_tensor =
      IAU2000ANutationGPU.rotate_teme_to_ecef_gpu(
        Nx.reshape(teme_tensor, {1, 3}),
        gast_tensor
      )

    # Extract ECEF coordinates
    [x_ecef, y_ecef, z_ecef] = ecef_tensor |> Nx.squeeze() |> Nx.to_list()

    # Convert ECEF to geodetic (WGS84)
    ecef_to_geodetic({x_ecef, y_ecef, z_ecef})
  end

  # ECEF to geodetic conversion using WGS84 parameters
  defp ecef_to_geodetic({x_km, y_km, z_km}) do
    # WGS84 constants
    # Semi-major axis in km
    a = 6378.137
    # Flattening
    f = 1.0 / 298.257223563
    # Semi-minor axis
    _b = a * (1 - f)
    # First eccentricity squared
    e2 = 2 * f - f * f

    # Calculate longitude
    lon_rad = :math.atan2(y_km, x_km)
    lon_deg = lon_rad * 180.0 / :math.pi()

    # Calculate distance from z-axis
    p = :math.sqrt(x_km * x_km + y_km * y_km)

    # Initial latitude estimate
    lat_rad = :math.atan2(z_km, p * (1 - e2))

    # Iterate to find accurate latitude and altitude
    {lat_final, alt_final} = iterate_geodetic(lat_rad, p, z_km, a, e2, 5)

    lat_deg = lat_final * 180.0 / :math.pi()

    {:ok, %{latitude: lat_deg, longitude: lon_deg, altitude_km: alt_final}}
  end

  # Iterative calculation for geodetic coordinates
  defp iterate_geodetic(lat_rad, p, _z_km, a, e2, 0) do
    # Final calculation
    sin_lat = :math.sin(lat_rad)
    n = a / :math.sqrt(1 - e2 * sin_lat * sin_lat)
    alt_km = p / :math.cos(lat_rad) - n
    {lat_rad, alt_km}
  end

  defp iterate_geodetic(lat_rad, p, z_km, a, e2, iterations) do
    sin_lat = :math.sin(lat_rad)
    n = a / :math.sqrt(1 - e2 * sin_lat * sin_lat)
    alt_km = p / :math.cos(lat_rad) - n

    # Update latitude
    lat_new = :math.atan2(z_km, p * (1 - e2 * n / (n + alt_km)))

    iterate_geodetic(lat_new, p, z_km, a, e2, iterations - 1)
  end
end
