defmodule SGP4NIF do
  @on_load :load_nif

  def load_nif do
    nif_path = Path.join(:code.priv_dir(:sgp4_ex), "sgp4_nif")

    case :erlang.load_nif(String.to_charlist(nif_path), 0) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.warn("Failed to load NIF: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @dialyzer {:no_match, propagate_tle: 3}
  @spec propagate_tle(binary(), binary(), float()) :: {:ok, map()} | {:error, any()}
  def propagate_tle(_line1, _line2, _tsince) do
    # fallback to return an error instead of raising
    {:error, :nif_not_loaded}
  end
end
