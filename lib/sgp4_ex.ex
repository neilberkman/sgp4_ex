defmodule Sgp4Ex do
  @moduledoc """
  SGP4 propagation module for Elixir.
  """

  alias Sgp4Ex.TLE
  alias Sgp4Ex.TemeState

  @microseconds_per_day 86_400 * 1_000_000

  @doc "parse a two line element set (TLE) from a string"
  def parse_tle(line1, line2) do
    # check to ensure each line is 69 characters
    case {String.length(line1), String.length(line2)} do
      # TLE has correct number of characters, proceed with parsing
      {69, 69} ->
        try do
          last_digits_of_year = String.to_integer(String.slice(line1, 18..19))
          current_year = Date.utc_today().year

          epoch_year =
            if last_digits_of_year > current_year - 2000 do
              1900 + last_digits_of_year
            else
              2000 + last_digits_of_year
            end

          # day 1 is 0 days from the start of the year
          day_of_year = String.to_float(String.slice(line1, 20..31)) - 1
          days_to_add = trunc(day_of_year)
          microseconds_to_add = trunc((day_of_year - days_to_add) * @microseconds_per_day)
          start_of_year = DateTime.new!(Date.new!(epoch_year, 1, 1), Time.new!(0, 0, 0, 0))

          epoch =
            DateTime.add(start_of_year, days_to_add, :day)
            |> DateTime.add(microseconds_to_add, :microsecond)

          mean_motion_double_dot =
            if String.at(line1, 44) == "-" do
              -1 * String.to_float(String.replace("0." <> String.slice(line1, 45..49), " ", "")) *
                Float.pow(10.0, String.to_integer(String.slice(line1, 50..51)))
            else
              String.to_float(String.replace("0." <> String.slice(line1, 45..49), " ", "")) *
                Float.pow(10.0, String.to_integer(String.slice(line1, 50..51)))
            end

          mean_motion_dot =
            if String.at(line1, 33) == "-" do
              -1 * String.to_float(String.replace("0" <> String.slice(line1, 34..42), " ", ""))
            else
              String.to_float(String.replace("0" <> String.slice(line1, 34..42), " ", ""))
            end

          b_star =
            if String.at(line1, 53) == "-" do
              -1 * String.to_float(String.replace("0." <> String.slice(line1, 54..58), " ", "")) *
                Float.pow(10.0, String.to_integer(String.slice(line1, 59..60)))
            else
              String.to_float(String.replace("0." <> String.slice(line1, 53..58), " ", "")) *
                Float.pow(10.0, String.to_integer(String.slice(line1, 59..60)))
            end

          tle = %TLE{
            # line 1 parameters
            line1: line1,
            catalog_number: String.replace(String.slice(line1, 2..6), " ", ""),
            classification: String.at(line1, 7),
            international_designator: String.replace(String.slice(line1, 9..16), " ", ""),
            epoch: epoch,
            mean_motion_dot: mean_motion_dot,
            mean_motion_double_dot: mean_motion_double_dot,
            bstar: b_star,
            ephemeris_type: String.to_integer(String.at(line1, 62)),
            elset_number:
              String.to_integer(String.replace(String.slice(line1, 64..67), " ", "")),

            # line 2 parameters
            line2: line2,
            inclination_deg: String.to_float(String.replace(String.slice(line2, 8..15), " ", "")),
            raan_deg: String.to_float(String.replace(String.slice(line2, 17..24), " ", "")),
            eccentricity:
              String.to_float(String.replace("0." <> String.slice(line2, 26..32), " ", "")),
            arg_perigee_deg: String.to_float(String.replace(String.slice(line2, 34..41), " ", "")),
            mean_anomaly_deg: String.to_float(String.replace(String.slice(line2, 43..50), " ", "")),
            mean_motion: String.to_float(String.replace(String.slice(line2, 52..62), " ", "")),
            rev_number: String.to_integer(String.replace(String.slice(line2, 63..67), " ", ""))
          }

          {:ok, tle}
        rescue
          ArgumentError -> {:error, "Unable to parse TLE- check all fields are correctly spaced"}
        end

      _ ->
        {:error, "Unable to parse TLE- line length is incorrect"}
    end
  end

  @spec propagate_tle_to_epoch(TLE.t(), DateTime.t()) :: {:ok, map()} | {:error, any()}
  def propagate_tle_to_epoch(tle, epoch) do
      tsince = DateTime.diff(epoch, tle.epoch, :millisecond) / 1.0e3

      # Call the NIF function to propagate the TLE
      case SGP4NIF.propagate_tle(tle.line1, tle.line2, tsince) do
        {:ok, data} ->
          {:ok, %TemeState{
            position: elem(data, 0),
            velocity: elem(data, 1)
          }
        }

        {:error, reason} ->
          {:error, reason}
      end
  end
end
