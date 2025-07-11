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
    use_cache = Keyword.get(opts, :use_cache, true)

    if use_cache do
      propagate_with_cache(tles, datetime, use_batch_nif)
    else
      # Original non-cached path
      if use_batch_nif and length(tles) > 1 do
        propagate_batch_nif(tles, datetime)
      else
        propagate_serial(tles, datetime)
      end
    end
  end

  # Serial propagation (simplest method)
  defp propagate_serial(tles, datetime) do
    Enum.map(tles, fn {line1, line2} ->
      case Sgp4Ex.parse_tle(line1, line2) do
        {:ok, tle} ->
          case Sgp4Ex.propagate_to_geodetic(tle, datetime) do
            {:ok, geodetic} -> {:ok, geodetic}
            {:error, reason} -> {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  # Cached propagation with optimization selection
  defp propagate_with_cache(tles, datetime, use_batch_nif) do
    if use_batch_nif and length(tles) > 1 do
      # Use batch NIF but with cached TLE parsing
      propagate_batch_cached(tles, datetime)
    else
      # Use SatelliteCache directly for each TLE
      propagate_serial_cached(tles, datetime)
    end
  end

  # Serial propagation using SatelliteCache
  defp propagate_serial_cached(tles, datetime) do
    # Use SatelliteCache directly - simplest and most cache-efficient
    Enum.map(tles, fn {line1, line2} ->
      Sgp4Ex.SatelliteCache.propagate_to_geodetic(line1, line2, datetime)
    end)
  end

  # Batch cached propagation
  defp propagate_batch_cached(tles, datetime) do
    # Group TLEs by their line1/line2 to minimize NIF calls
    grouped = Enum.group_by(tles, fn {line1, line2} -> {line1, line2} end)

    # Process each unique TLE
    Enum.flat_map(grouped, fn {{line1, line2}, group} ->
      # Calculate tsince for this TLE
      case Sgp4Ex.parse_tle(line1, line2) do
        {:ok, tle} ->
          epoch = tle.epoch
          tsince = calculate_tsince(epoch, datetime)

          # Batch propagate this TLE
          case SGP4NIF.propagate_tle_batch(line1, line2, [tsince]) do
            {:ok, [batch_result]} ->
              # Convert TEME to geodetic using standard coordinate system
              case batch_result do
                {:ok, {x, y, z, vx, vy, vz}} ->
                  case Sgp4Ex.CoordinateSystems.teme_to_geodetic({x, y, z}, datetime) do
                    {:ok, geodetic} -> List.duplicate({:ok, geodetic}, length(group))
                    {:error, reason} -> List.duplicate({:error, reason}, length(group))
                  end

                {:error, reason} ->
                  List.duplicate({:error, reason}, length(group))
              end

            {:error, reason} ->
              List.duplicate({:error, reason}, length(group))
          end

        {:error, reason} ->
          List.duplicate({:error, reason}, length(group))
      end
    end)
  end

  # Batch NIF propagation
  defp propagate_batch_nif(tles, datetime) do
    # Group TLEs by their line1/line2 to minimize NIF calls
    grouped = Enum.group_by(tles, fn {line1, line2} -> {line1, line2} end)

    # Process each unique TLE
    Enum.flat_map(grouped, fn {{line1, line2}, group} ->
      # Calculate tsince for this TLE
      case Sgp4Ex.parse_tle(line1, line2) do
        {:ok, tle} ->
          epoch = tle.epoch
          tsince_list = Enum.map(group, fn _ -> calculate_tsince(epoch, datetime) end)

          # Batch propagate this TLE
          case SGP4NIF.propagate_tle_batch(line1, line2, tsince_list) do
            {:ok, batch_results} ->
              # Convert TEME positions to geodetic
              Enum.map(batch_results, fn batch_result ->
                case batch_result do
                  {:ok, {x, y, z, vx, vy, vz}} ->
                    case Sgp4Ex.CoordinateSystems.teme_to_geodetic({x, y, z}, datetime) do
                      {:ok, geodetic} -> {:ok, geodetic}
                      {:error, reason} -> {:error, reason}
                    end

                  {:error, reason} ->
                    {:error, reason}
                end
              end)

            {:error, reason} ->
              List.duplicate({:error, reason}, length(group))
          end

        {:error, reason} ->
          List.duplicate({:error, reason}, length(group))
      end
    end)
  end

  # Helper function to calculate time since epoch
  defp calculate_tsince(epoch, datetime) do
    epoch_seconds = DateTime.to_unix(epoch, :second)
    target_seconds = DateTime.to_unix(datetime, :second)
    (target_seconds - epoch_seconds) / 60.0
  end
end