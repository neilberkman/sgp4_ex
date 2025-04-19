defmodule SGP4NIF do
  @on_load :load_nif

  def load_nif do
    nif_path = Path.join(:code.priv_dir(:sgp4_nif), "sgp4_nif")
    :erlang.load_nif(String.to_charlist(nif_path), 0)
  end

  # fallback if NIF fails to load
  def propagate_tle(_line1, _line2, _tsince) do
    raise "NIF propagate_tle/3 not implemented"
  end
end
