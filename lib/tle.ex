defmodule Sgp4Ex.TLE do
  @moduledoc """
  A module for handling TLE (Two-Line Element) data.
  """

  @type t :: %__MODULE__{
          line1: String.t(),
          line2: String.t(),
          catalog_number: String.t(),
          classification: String.t(),
          international_designator: String.t(),
          epoch: DateTime.t(),
          mean_motion_dot: float(),
          mean_motion_double_dot: float(),
          bstar: float(),
          ephemeris_type: integer(),
          elset_number: integer(),
          inclination_deg: float(),
          raan_deg: float(),
          eccentricity: float(),
          arg_perigee_deg: float(),
          mean_anomaly_deg: float(),
          mean_motion: float(),
          rev_number: integer()
        }

  defstruct [
    :line1,
    :line2,
    :catalog_number,
    :classification,
    :international_designator,
    :epoch,
    :mean_motion_dot,
    :mean_motion_double_dot,
    :bstar,
    :ephemeris_type,
    :elset_number,
    :inclination_deg,
    :raan_deg,
    :eccentricity,
    :arg_perigee_deg,
    :mean_anomaly_deg,
    :mean_motion,
    :rev_number
  ]
end
