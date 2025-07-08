defmodule Sgp4Ex do
  @moduledoc """
  SGP4 propagation module for Elixir.
  """

  alias Sgp4Ex.TLE
  alias Sgp4Ex.TemeState

  @microseconds_per_day 86_400 * 1_000_000

  # Helper to parse floats that may have leading dots (like .123 instead of 0.123)
  defp parse_float(str) do
    trimmed = String.trim(str)
    # Add leading 0 if string starts with . or -.
    normalized =
      case trimmed do
        "." <> _ -> "0" <> trimmed
        "-." <> rest -> "-0." <> rest
        _ -> trimmed
      end

    String.to_float(normalized)
  end

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
  def parse_tle(longstr1, longstr2) do
    with :ok <- validate_ascii(longstr1, longstr2),
         line1 <- clean_tle_line(longstr1, 69),
         line2 <- clean_tle_line(longstr2, 69),
         :ok <- validate_line_format(line1, line2),
         {:ok, fields} <- extract_tle_fields(line1, line2) do
      {:ok, build_tle_struct(fields, line1, line2)}
    end
  end

  defp validate_ascii(line1, line2) do
    if String.to_charlist(line1) |> Enum.all?(&(&1 <= 127)) and
         String.to_charlist(line2) |> Enum.all?(&(&1 <= 127)) do
      :ok
    else
      {:error, "TLE lines contain non-ASCII characters"}
    end
  end

  defp clean_tle_line(line, max_length) do
    line
    |> remove_trailing_whitespace()
    |> truncate_to_valid_tle_length(max_length)
  end

  defp remove_trailing_whitespace(line), do: String.trim_trailing(line)

  defp truncate_to_valid_tle_length(line, max_length) when byte_size(line) > max_length do
    String.slice(line, 0..(max_length - 1))
  end

  defp truncate_to_valid_tle_length(line, _max_length), do: line

  defp validate_line_format(line1, line2) do
    with :ok <- validate_line1_positions(line1),
         :ok <- validate_line2_positions(line2),
         :ok <- validate_matching_satellite_numbers(line1, line2) do
      :ok
    end
  end

  defp validate_line1_positions(line) do
    cond do
      String.length(line) < 64 ->
        {:error, format_error_message()}

      not String.starts_with?(line, "1 ") ->
        {:error, format_error_message()}

      not all_positions_valid?(line, line1_positions()) ->
        {:error, format_error_message()}

      true ->
        :ok
    end
  end

  defp validate_line2_positions(line) do
    cond do
      String.length(line) < 68 ->
        {:error, format_error_message()}

      not String.starts_with?(line, "2 ") ->
        {:error, format_error_message()}

      not all_positions_valid?(line, line2_positions()) ->
        {:error, format_error_message()}

      true ->
        :ok
    end
  end

  defp all_positions_valid?(line, positions) do
    Enum.all?(positions, fn {pos, expected_char} ->
      String.at(line, pos) == expected_char
    end)
  end

  defp line1_positions do
    [{8, " "}, {23, "."}, {32, " "}, {34, "."}, {43, " "}, {52, " "}, {61, " "}, {63, " "}]
  end

  defp line2_positions do
    [
      {7, " "},
      {11, "."},
      {16, " "},
      {20, "."},
      {25, " "},
      {33, " "},
      {37, "."},
      {42, " "},
      {46, "."},
      {51, " "}
    ]
  end

  defp validate_matching_satellite_numbers(line1, line2) do
    if String.slice(line1, 2..6) == String.slice(line2, 2..6) do
      :ok
    else
      {:error, "Object numbers in lines 1 and 2 do not match"}
    end
  end

  defp format_error_message do
    "TLE format error\n\nThe Two-Line Element (TLE) format was designed for punch cards, and so\nis very strict about the position of every period, space, and digit.\nYour line does not quite match."
  end

  defp extract_tle_fields(line1, line2) do
    try do
      fields = %{
        catalog_number: String.slice(line1, 2..6),
        classification: String.at(line1, 7) || "U",
        intldesg: String.trim_trailing(String.slice(line1, 9..16)),
        two_digit_year: String.slice(line1, 18..19) |> String.trim() |> String.to_integer(),
        epochdays: String.slice(line1, 20..31) |> parse_float(),
        ndot: String.slice(line1, 33..42) |> parse_float(),
        nddot: parse_nddot(line1),
        bstar: parse_bstar(line1),
        ephtype: String.at(line1, 62) |> String.to_integer(),
        elnum: String.slice(line1, 64..67) |> String.trim() |> String.to_integer(),
        inclo: String.slice(line2, 8..15) |> parse_float(),
        nodeo: String.slice(line2, 17..24) |> parse_float(),
        ecco: parse_eccentricity(line2),
        argpo: String.slice(line2, 34..41) |> parse_float(),
        mo: String.slice(line2, 43..50) |> parse_float(),
        no_kozai: String.slice(line2, 52..62) |> parse_float(),
        revnum: String.slice(line2, 63..67) |> String.trim() |> String.to_integer()
      }

      {:ok, fields}
    rescue
      e -> {:error, "TLE format error: #{Exception.message(e)}"}
    end
  end

  defp parse_nddot(line1) do
    sign = if String.at(line1, 44) == "-", do: -1, else: 1
    mantissa = ("0." <> String.slice(line1, 45..49)) |> String.trim() |> String.to_float()
    exp = String.slice(line1, 50..51) |> String.trim() |> String.to_integer()
    sign * mantissa * :math.pow(10.0, exp)
  end

  defp parse_bstar(line1) do
    sign = if String.at(line1, 53) == "-", do: -1, else: 1
    mantissa = ("0." <> String.slice(line1, 54..58)) |> String.trim() |> String.to_float()
    exp = String.slice(line1, 59..60) |> String.trim() |> String.to_integer()
    sign * mantissa * :math.pow(10.0, exp)
  end

  defp parse_eccentricity(line2) do
    ("0." <> String.replace(String.slice(line2, 26..32), " ", "0")) |> String.to_float()
  end

  defp build_tle_struct(fields, line1, line2) do
    epoch_year =
      if fields.two_digit_year < 57,
        do: 2000 + fields.two_digit_year,
        else: 1900 + fields.two_digit_year

    epoch = calculate_epoch(epoch_year, fields.epochdays)

    %TLE{
      line1: line1,
      line2: line2,
      catalog_number: fields.catalog_number,
      classification: fields.classification,
      international_designator: fields.intldesg,
      epoch: epoch,
      mean_motion_dot: fields.ndot,
      mean_motion_double_dot: fields.nddot,
      bstar: fields.bstar,
      ephemeris_type: fields.ephtype,
      elset_number: fields.elnum,
      inclination_deg: fields.inclo,
      raan_deg: fields.nodeo,
      eccentricity: fields.ecco,
      arg_perigee_deg: fields.argpo,
      mean_anomaly_deg: fields.mo,
      mean_motion: fields.no_kozai,
      rev_number: fields.revnum
    }
  end

  defp calculate_epoch(epoch_year, epochdays) do
    days_from_jan1 = epochdays - 1
    whole_days = trunc(days_from_jan1)
    fractional_day = days_from_jan1 - whole_days

    start_of_year = DateTime.new!(Date.new!(epoch_year, 1, 1), Time.new!(0, 0, 0, 0))
    epoch_with_days = DateTime.add(start_of_year, whole_days, :day)

    microseconds = trunc(fractional_day * @microseconds_per_day)
    DateTime.add(epoch_with_days, microseconds, :microsecond)
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
        # NIF returns position in meters and velocity in m/s
        # Convert to km and km/s for consistency
        {x_m, y_m, z_m} = elem(data, 0)
        {vx_m, vy_m, vz_m} = elem(data, 1)

        {:ok,
         %TemeState{
           position: {x_m / 1000.0, y_m / 1000.0, z_m / 1000.0},
           velocity: {vx_m / 1000.0, vy_m / 1000.0, vz_m / 1000.0}
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Propagate a TLE to geodetic coordinates at a specific epoch.

  This is a convenience function that propagates the satellite position and
  converts it to geodetic coordinates (latitude, longitude, altitude).

  ## Parameters
  - `tle`: The TLE data structure containing the satellite's orbital elements
  - `epoch`: The UTC datetime to which the TLE should be propagated

  ## Returns
  - `{:ok, %{latitude: float, longitude: float, altitude_km: float}}` where:
    - `latitude`: Geodetic latitude in degrees (-90 to 90)
    - `longitude`: Geodetic longitude in degrees (-180 to 180)
    - `altitude_km`: Height above WGS84 ellipsoid in kilometers
  - `{:error, String.t()}`: An error message if propagation fails

  ## Example
      iex> {:ok, tle} = Sgp4Ex.parse_tle(
      ...>   "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993",
      ...>   "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"
      ...> )
      iex> epoch = ~U[2021-10-02T14:00:00Z]
      iex> case Sgp4Ex.propagate_to_geodetic(tle, epoch) do
      ...>   {:ok, %{latitude: lat, longitude: lon, altitude_km: alt}} when is_float(lat) and is_float(lon) and is_float(alt) -> :ok
      ...>   _ -> :error
      ...> end
      :ok
  """
  @spec propagate_to_geodetic(TLE.t(), DateTime.t()) ::
          {:ok, %{latitude: float(), longitude: float(), altitude_km: float()}}
          | {:error, String.t()}
  def propagate_to_geodetic(%TLE{} = tle, %DateTime{} = epoch) do
    alias Sgp4Ex.CoordinateSystems

    case propagate_tle_to_epoch(tle, epoch) do
      {:ok, %TemeState{position: position}} ->
        CoordinateSystems.teme_to_geodetic(position, epoch)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
