defmodule SGP4NIF do
  @moduledoc """
  Native Implemented Functions for SGP4 satellite propagation.

  This module provides the low-level interface to the C++ SGP4 implementation,
  supporting both batch operations and stateful satellite resources.
  """

  @on_load :load_nif

  def load_nif do
    priv_dir = :code.priv_dir(:sgp4_ex)
    nif_path = Path.join(priv_dir, "sgp4_nif")

    case :erlang.load_nif(String.to_charlist(nif_path), 0) do
      :ok ->
        IO.puts("✅ Loaded unified NIF (batch + stateful functions)")
        :ok

      {:error, reason} ->
        IO.warn("Failed to load NIF: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Stateful API functions

  @doc """
  Initialize a satellite from TLE lines.

  Returns a NIF resource that can be used for multiple propagations.
  This matches Python's Satrec.twoline2rv() function.
  """
  def init_satellite(_line1, _line2) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Propagate an initialized satellite to a specific time.

  Takes a satellite resource and time since epoch in minutes.
  Returns position and velocity vectors in meters and meters/second.
  This matches Python's satrec.sgp4() function.
  """
  def propagate_satellite(_satellite_resource, _tsince_minutes) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Get information about an initialized satellite.

  Returns satellite parameters and metadata.
  """
  def get_satellite_info(_satellite_resource) do
    :erlang.nif_error(:nif_not_loaded)
  end

  # Legacy/Batch API functions

  @doc """
  Legacy function for backward compatibility.
  Propagates a TLE to a specific time, initializing and cleaning up in one call.
  """
  @spec propagate_tle(binary(), binary(), float()) :: {:ok, map()} | {:error, any()}
  def propagate_tle(_line1, _line2, _tsince) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Batch propagation using OpenMP parallelization.
  Propagates a TLE to multiple epochs in parallel.

  ## Parameters
  - `line1`: First line of TLE
  - `line2`: Second line of TLE
  - `tsince_list`: List of times since epoch in minutes

  ## Returns
  - `{:ok, results}` where results is a list of `{:ok, state}` or `{:error, reason}`
  - `{:error, reason}` if TLE initialization fails
  """
  @spec propagate_tle_batch(binary(), binary(), [float()]) :: {:ok, list()} | {:error, any()}
  def propagate_tle_batch(_line1, _line2, _tsince_list) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
