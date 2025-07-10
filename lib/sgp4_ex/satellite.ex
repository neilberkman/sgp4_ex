defmodule Sgp4Ex.Satellite do
  @moduledoc """
  Stateful satellite management for efficient multi-epoch propagation.

  This module uses Cachex for high-performance caching and matches Python SGP4's pattern:
  - Initialize satellite once with TLE data
  - Propagate to multiple epochs without re-initialization

  ## Example

      # Initialize once
      {:ok, satellite} = Sgp4Ex.Satellite.init(line1, line2)

      # Propagate many times efficiently
      {:ok, state1} = Sgp4Ex.Satellite.propagate(satellite, epoch1)
      {:ok, state2} = Sgp4Ex.Satellite.propagate(satellite, epoch2)

      # Or propagate many at once
      {:ok, states} = Sgp4Ex.Satellite.propagate_many(satellite, [epoch1, epoch2, epoch3])

      # Get cache statistics
      {:ok, stats} = Sgp4Ex.Satellite.stats()
  """

  require Logger

  alias Sgp4Ex.TemeState
  alias Sgp4Ex.CoordinateSystems

  @cache_name :sgp4_satellites

  # Default cache options
  @default_cache_opts [
    # Max 10k satellites
    limit: 10_000,
    # 24 hour TTL
    ttl: :timer.hours(24),
    # Enable statistics
    stats: true,
    # Enable transactions for batch operations
    transactions: true
  ]

  # Client API

  @doc """
  Start the satellite cache.

  ## Options

  - `:limit` - Maximum number of satellites to cache (default: 10,000)
  - `:ttl` - Time to live in milliseconds (default: 24 hours)
  - `:stats` - Enable statistics tracking (default: true)
  """
  def start_link(opts \\ []) do
    cache_opts = Keyword.merge(@default_cache_opts, opts)
    Cachex.start_link(@cache_name, cache_opts)
  end

  @doc """
  Initialize a satellite from TLE lines.

  Returns an opaque reference that can be used for propagation.
  The satellite is automatically cached and will be cleaned up based on TTL.
  """
  @spec init(String.t(), String.t()) :: {:ok, reference()} | {:error, String.t()}
  def init(line1, line2) do
    tle_hash = :crypto.hash(:sha256, line1 <> line2)

    # Use Cachex's fetch to only initialize if not already cached
    case Cachex.fetch(@cache_name, tle_hash, fn _key ->
           case SGP4NIF.init_satellite(line1, line2) do
             {:ok, nif_resource} ->
               sat_ref = make_ref()

               satellite_data = %{
                 ref: sat_ref,
                 resource: nif_resource,
                 line1: line1,
                 line2: line2,
                 tle_hash: tle_hash,
                 created_at: System.system_time(:millisecond)
               }

               # Store both by hash and by ref for fast lookups
               Cachex.put(@cache_name, sat_ref, satellite_data)
               {:commit, sat_ref}

             {:error, reason} ->
               {:ignore, {:error, reason}}
           end
         end) do
      {:ok, sat_ref} -> {:ok, sat_ref}
      {:commit, sat_ref} -> {:ok, sat_ref}
      {:ignore, error} -> error
      {:error, :no_cache} -> {:error, :no_cache}
    end
  end

  @doc """
  Propagate a satellite to a specific epoch.

  Uses the pre-initialized satellite for efficient propagation.
  """
  @spec propagate(reference(), DateTime.t()) :: {:ok, TemeState.t()} | {:error, String.t()}
  def propagate(sat_ref, epoch) do
    case Cachex.get(@cache_name, sat_ref) do
      {:ok, nil} ->
        {:error, "Satellite not found"}

      {:ok, %{resource: nif_resource, line1: line1, line2: line2}} ->
        # Parse TLE to get epoch
        {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
        tsince_minutes = DateTime.diff(epoch, tle.epoch, :microsecond) / 60_000_000.0

        case SGP4NIF.propagate_satellite(nif_resource, tsince_minutes) do
          {:ok, {position, velocity}} ->
            # Convert from meters to kilometers
            {x_m, y_m, z_m} = position
            {vx_m, vy_m, vz_m} = velocity

            teme_state = %TemeState{
              position: {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0},
              velocity: {vx_m / 1000.0, vy_m / 1000.0, vz_m / 1000.0}
            }

            # Update last accessed time
            Cachex.touch(@cache_name, sat_ref)

            {:ok, teme_state}

          error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Propagate a satellite to multiple epochs efficiently.

  Returns a list of results in the same order as the input epochs.
  """
  @spec propagate_many(reference(), [DateTime.t()]) ::
          {:ok, [TemeState.t()]} | {:error, String.t()}
  def propagate_many(sat_ref, epochs) when is_list(epochs) do
    case Cachex.get(@cache_name, sat_ref) do
      {:ok, nil} ->
        {:error, "Satellite not found"}

      {:ok, %{resource: nif_resource, line1: line1, line2: line2}} ->
        # Parse TLE once
        {:ok, tle} = Sgp4Ex.parse_tle(line1, line2)

        # Use transaction for batch operation
        Cachex.transaction(@cache_name, [sat_ref], fn ->
          results =
            Enum.map(epochs, fn epoch ->
              tsince_minutes = DateTime.diff(epoch, tle.epoch, :microsecond) / 60_000_000.0

              case SGP4NIF.propagate_satellite(nif_resource, tsince_minutes) do
                {:ok, {position, velocity}} ->
                  # Convert from meters to kilometers
                  {x_m, y_m, z_m} = position
                  {vx_m, vy_m, vz_m} = velocity

                  %TemeState{
                    position: {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0},
                    velocity: {vx_m / 1000.0, vy_m / 1000.0, vz_m / 1000.0}
                  }

                {:error, _reason} ->
                  nil
              end
            end)

          # Update last accessed time
          Cachex.touch(@cache_name, sat_ref)

          if Enum.any?(results, &is_nil/1) do
            {:error, "Some propagations failed"}
          else
            {:ok, results}
          end
        end)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Propagate to geodetic coordinates at a specific epoch.
  """
  @spec propagate_to_geodetic(reference(), DateTime.t(), keyword()) ::
          {:ok, %{latitude: float(), longitude: float(), altitude_km: float()}}
          | {:error, String.t()}
  def propagate_to_geodetic(sat_ref, epoch, opts \\ []) do
    case propagate(sat_ref, epoch) do
      {:ok, %TemeState{position: position}} ->
        CoordinateSystems.teme_to_geodetic(position, epoch, opts)

      error ->
        error
    end
  end

  @doc """
  Propagate to geodetic coordinates at multiple epochs.
  """
  @spec propagate_many_to_geodetic(reference(), [DateTime.t()], keyword()) ::
          [
            {:ok, %{latitude: float(), longitude: float(), altitude_km: float()}}
            | {:error, String.t()}
          ]
  def propagate_many_to_geodetic(sat_ref, epochs, opts \\ []) when is_list(epochs) do
    case propagate_many(sat_ref, epochs) do
      {:ok, states} ->
        Enum.zip(states, epochs)
        |> Enum.map(fn {%TemeState{position: position}, epoch} ->
          CoordinateSystems.teme_to_geodetic(position, epoch, opts)
        end)

      {:error, reason} ->
        Enum.map(epochs, fn _ -> {:error, reason} end)
    end
  end

  @doc """
  Get information about an initialized satellite.
  """
  @spec info(reference()) :: {:ok, map()} | {:error, String.t()}
  def info(sat_ref) do
    case Cachex.get(@cache_name, sat_ref) do
      {:ok, nil} ->
        {:error, "Satellite not found"}

      {:ok, satellite_data} ->
        case SGP4NIF.get_satellite_info(satellite_data.resource) do
          {:ok, info} ->
            {:ok,
             Map.merge(info, %{
               created_at: satellite_data.created_at,
               tle_hash: satellite_data.tle_hash
             })}

          error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Release a satellite resource.

  This is optional - resources are automatically cleaned up based on TTL.
  """
  @spec release(reference()) :: :ok
  def release(sat_ref) do
    Cachex.del(@cache_name, sat_ref)
    :ok
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    case Cachex.stats(@cache_name) do
      {:ok, stats} ->
        {:ok,
         %{
           hits: stats.hits,
           misses: stats.misses,
           evictions: stats.evictions,
           operations: stats.operations,
           size: Cachex.size(@cache_name) |> elem(1)
         }}

      error ->
        error
    end
  end

  @doc """
  Clear all cached satellites.
  """
  def clear do
    Cachex.clear(@cache_name)
  end

  @doc """
  Warm the cache with frequently used satellites.

  Accepts a list of {line1, line2} tuples.
  """
  def warm(tle_list) when is_list(tle_list) do
    results =
      Enum.map(tle_list, fn {line1, line2} ->
        init(line1, line2)
      end)

    successful =
      Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    {:ok, %{loaded: successful, failed: length(tle_list) - successful}}
  end
end
