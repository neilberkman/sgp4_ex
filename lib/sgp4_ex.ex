defmodule Sgp4Ex do
  @moduledoc """
  SGP4 propagation module for Elixir.
  """

  alias Sgp4Ex.TLE
  alias Sgp4Ex.TemeState

  @microseconds_per_day 86_400 * 1_000_000

  @doc """
  Parse a TLE (Two-Line Element) set into a TLE struct.
  The TLE consists of two lines, each with a specific format.

  ## Parameters
  - `line1`: The first line of the TLE.
  - `line2`: The second line of the TLE.

  ## Returns
  - `{:ok, TLE.t()}`: The parsed TLE struct.
  - `{:error, String.t()}`: An error message if the parsing fails.

  ## Example
      iex> line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
      iex> line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"
      iex> case Sgp4Ex.parse_tle(line1, line2) do
      ...>   {:ok, %Sgp4Ex.TLE{}} -> :ok
      ...>   _ -> :error
      ...> end
      :ok
  """
  @spec parse_tle(String.t(), String.t()) :: {:ok, TLE.t()} | {:error, String.t()}
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
            elset_number: String.to_integer(String.replace(String.slice(line1, 64..67), " ", "")),

            # line 2 parameters
            line2: line2,
            inclination_deg: String.to_float(String.replace(String.slice(line2, 8..15), " ", "")),
            raan_deg: String.to_float(String.replace(String.slice(line2, 17..24), " ", "")),
            eccentricity:
              String.to_float(String.replace("0." <> String.slice(line2, 26..32), " ", "")),
            arg_perigee_deg:
              String.to_float(String.replace(String.slice(line2, 34..41), " ", "")),
            mean_anomaly_deg:
              String.to_float(String.replace(String.slice(line2, 43..50), " ", "")),
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

  @doc """
  Propagate a TLE to a specific epoch using the SGP4 algorithm.
  The epoch is the time to which the TLE should be propagated.

  ## Parameters
  - `tle`: The TLE data structure containing the satellite's orbital elements.
  - `epoch`: The epoch to which the TLE should be propagated.

  ## Returns
  - `{:ok, TemeState.t()}`: The propagated Teme state of the satellite.
  - `{:error, String.t()}`: An error message if the propagation fails.

  ## Example
      iex> {:ok, tle} = Sgp4Ex.parse_tle(
      ...>   "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993",
      ...>   "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"
      ...> )
      iex> epoch = ~U[2021-10-02T14:00:00Z]
      iex> case Sgp4Ex.propagate_tle_to_epoch(tle, epoch) do
      ...>   {:ok, %Sgp4Ex.TemeState{position: {x, y, z}, velocity: {vx, vy, vz}}} when is_float(x) and is_float(y) and is_float(z) and is_float(vx) and is_float(vy) and is_float(vz) -> :ok
      ...>   _ -> :error
      ...> end
      :ok
  """
  @spec propagate_tle_to_epoch(TLE.t(), DateTime.t()) ::
          {:ok, TemeState.t()} | {:error, String.t()}
  def propagate_tle_to_epoch(tle, epoch) do
    tsince = DateTime.diff(epoch, tle.epoch, :millisecond) * 1.0e-3

    # Call the NIF function to propagate the TLE
    case apply(SGP4NIF, :propagate_tle, [tle.line1, tle.line2, tsince]) do
      {:ok, data} ->
        {:ok,
         %TemeState{
           position: elem(data, 0),
           velocity: elem(data, 1)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
