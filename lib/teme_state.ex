defmodule Sgp4Ex.TemeState do
  @moduledoc """
  A module for representing the Teme state of a satellite.
  """

  @type t :: %__MODULE__{
    position: {float(), float(), float()},
    velocity: {float(), float(), float()}
  }

  defstruct [
    :position,
    :velocity
  ]
end
