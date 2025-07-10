defmodule Sgp4Ex.Propagator do
  @moduledoc """
  High-level propagation API that provides both stateless and stateful interfaces.

  This module offers a unified API for satellite propagation with automatic
  optimization for batch operations. It internally uses the stateful Satellite
  API when beneficial.

  ## Examples

      # Single propagation (stateless)
      {:ok, result} = Sgp4Ex.Propagator.propagate_to_geodetic(line1, line2, epoch)
      
      # Batch propagation (automatically optimized)
      results = Sgp4Ex.Propagator.propagate_many_to_geodetic(line1, line2, epochs)
      
      # Explicit stateful usage
      {:ok, sat} = Sgp4Ex.Propagator.init_satellite(line1, line2)
      {:ok, result} = Sgp4Ex.Propagator.propagate(sat, epoch)
  """

  alias Sgp4Ex.Satellite

  @doc """
  Initialize a satellite for stateful propagation.

  This is equivalent to Python's `Satrec.twoline2rv()`.
  """
  defdelegate init_satellite(line1, line2), to: Satellite, as: :init

  @doc """
  Propagate an initialized satellite to an epoch.

  This is equivalent to Python's `satrec.sgp4()`.
  """
  defdelegate propagate(sat_ref, epoch), to: Satellite

  @doc """
  Propagate an initialized satellite to multiple epochs.

  This is equivalent to Python's `satrec.sgp4_array()`.
  """
  defdelegate propagate_many(sat_ref, epochs), to: Satellite

  @doc """
  Single propagation from TLE to geodetic coordinates.

  Uses caching to avoid re-parsing TLEs for improved performance.
  For more control, consider using `init_satellite/2` followed by `propagate/2`.
  """
  def propagate_to_geodetic(line1, line2, epoch, opts \\ []) do
    # Use cached TLE parsing for better performance
    Sgp4Ex.SatelliteCache.propagate_to_geodetic(line1, line2, epoch, opts)
  end

  @doc """
  Batch propagation from TLE to geodetic coordinates.

  Uses caching for optimal performance across all batch sizes.
  """
  def propagate_many_to_geodetic(line1, line2, epochs, opts \\ []) when is_list(epochs) do
    # Use cached approach for all batch sizes
    Sgp4Ex.SatelliteCache.propagate_many_to_geodetic(line1, line2, epochs, opts)
  end

  @doc """
  Get information about an initialized satellite.
  """
  defdelegate info(sat_ref), to: Satellite

  @doc """
  Release a satellite resource.

  This is optional as resources are automatically cleaned up,
  but can be used for explicit resource management.
  """
  defdelegate release(sat_ref), to: Satellite

  @doc """
  Propagate from TLE to TEME state vectors.

  Lower-level API that returns position and velocity vectors
  in the TEME reference frame.
  """
  def propagate_to_teme(line1, line2, epoch) do
    with {:ok, tle} <- Sgp4Ex.parse_tle(line1, line2),
         {:ok, state} <- Sgp4Ex.propagate_tle_to_epoch(tle, epoch) do
      {:ok, state}
    end
  end

  @doc """
  Batch propagation from TLE to TEME state vectors.
  """
  def propagate_many_to_teme(line1, line2, epochs) when is_list(epochs) do
    case length(epochs) do
      0 ->
        []

      1 ->
        [propagate_to_teme(line1, line2, hd(epochs))]

      _ ->
        with {:ok, sat_ref} <- Satellite.init(line1, line2),
             {:ok, states} <- Satellite.propagate_many(sat_ref, epochs) do
          Satellite.release(sat_ref)
          Enum.map(states, &{:ok, &1})
        else
          {:error, reason} ->
            Enum.map(epochs, fn _ -> {:error, reason} end)
        end
    end
  end
end
