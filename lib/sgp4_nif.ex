defmodule SGP4NIF do
  @moduledoc false
  @on_load :load_nif

  def load_nif do
    nif_path = Path.join(:code.priv_dir(:sgp4_ex), "sgp4_nif")

    case :erlang.load_nif(String.to_charlist(nif_path), 0) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec propagate_with_elements(map(), tuple()) :: {:ok, tuple()} | {:error, any()}
  def propagate_with_elements(_tle_map, _datetime_tuple), do: raise("NIF not loaded")

  @spec teme_to_gcrs(float(), float(), float(), float(), float(), float(), tuple()) ::
          {{float(), float(), float()}, {float(), float(), float()}}
  def teme_to_gcrs(_x, _y, _z, _vx, _vy, _vz, _datetime), do: raise("NIF not loaded")
end
