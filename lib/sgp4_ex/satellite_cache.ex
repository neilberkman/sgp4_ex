defmodule Sgp4Ex.SatelliteCache do
  @moduledoc """
  Satellite TLE caching using Cachex for improved performance.

  This module provides a clean interface for caching parsed TLEs to avoid
  re-initialization overhead when propagating the same satellite to multiple epochs.
  """

  @cache_name :sgp4_satellite_cache

  @doc """
  Propagate a satellite to geodetic coordinates, using cached TLE if available.
  """
  def propagate_to_geodetic(line1, line2, epoch, opts \\ []) do
    case get_or_parse_tle(line1, line2) do
      {:ok, tle} -> Sgp4Ex.propagate_to_geodetic(tle, epoch, opts)
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Propagate to multiple epochs efficiently using the same cached satellite.
  """
  def propagate_many_to_geodetic(line1, line2, epochs, opts \\ []) when is_list(epochs) do
    case get_or_parse_tle(line1, line2) do
      {:ok, tle} ->
        Enum.map(epochs, fn epoch ->
          Sgp4Ex.propagate_to_geodetic(tle, epoch, opts)
        end)

      {:error, _reason} = error ->
        # Return the same error for all epochs
        Enum.map(epochs, fn _epoch -> error end)
    end
  end

  @doc """
  Clear the satellite cache.
  """
  def clear_cache do
    Cachex.clear(@cache_name)
  end

  @doc """
  Get a parsed TLE from cache or parse it if not cached.
  Useful for integration with other modules.
  """
  def get_parsed_tle(line1, line2) do
    get_or_parse_tle(line1, line2)
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    case Process.whereis(@cache_name) do
      nil ->
        %{hits: 0, misses: 0, hit_rate: 0, cache_size: 0}

      _pid ->
        case Cachex.stats(@cache_name) do
          {:ok, stats} ->
            %{
              hits: Map.get(stats, :hits, 0),
              misses: Map.get(stats, :misses, 0),
              hit_rate: Map.get(stats, :hit_rate, 0),
              cache_size: Cachex.size!(@cache_name)
            }

          {:error, _} ->
            %{hits: 0, misses: 0, hit_rate: 0, cache_size: 0}
        end
    end
  end

  # Private functions

  defp get_or_parse_tle(line1, line2) do
    key = {line1, line2}

    # Check if cache is running, fallback to direct parsing if not
    case Process.whereis(@cache_name) do
      nil ->
        # Cache not running, parse directly
        Sgp4Ex.parse_tle(line1, line2)

      _pid ->
        # Cache is running, use it
        case Cachex.get(@cache_name, key) do
          {:ok, tle} when tle != nil ->
            {:ok, tle}

          _ ->
            # Cache miss, parse and cache the TLE
            case Sgp4Ex.parse_tle(line1, line2) do
              {:ok, tle} ->
                Cachex.put(@cache_name, key, tle)
                {:ok, tle}

              {:error, _reason} = error ->
                # Don't cache errors
                error
            end
        end
    end
  end
end
