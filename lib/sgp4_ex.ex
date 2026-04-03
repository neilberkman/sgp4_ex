defmodule Sgp4Ex do
  @moduledoc """
  SGP4 satellite orbit propagation with Skyfield-compatible TEME→GCRS
  coordinate transformation.
  """

  alias Sgp4Ex.TemeState
  alias Sgp4Ex.TLE

  @microseconds_per_day 86_400 * 1_000_000

  def teme_to_gcrs(%{position: {x, y, z}, velocity: {vx, vy, vz}}, datetime) do
    datetime_tuple =
      case datetime do
        {{_year, _month, _day}, {_hour, _minute, _second}} ->
          {elem(datetime, 0),
           {elem(elem(datetime, 1), 0), elem(elem(datetime, 1), 1), elem(elem(datetime, 1), 2), 0}}

        %DateTime{} ->
          microseconds = elem(datetime.microsecond, 0)

          {{datetime.year, datetime.month, datetime.day},
           {datetime.hour, datetime.minute, datetime.second, microseconds}}
      end

    {{x_gcrs, y_gcrs, z_gcrs}, {vx_gcrs, vy_gcrs, vz_gcrs}} =
      SGP4NIF.teme_to_gcrs(x, y, z, vx, vy, vz, datetime_tuple)

    %{
      position: {x_gcrs, y_gcrs, z_gcrs},
      velocity: {vx_gcrs, vy_gcrs, vz_gcrs}
    }
  end

  # Helper to parse floats that may have leading dots (like .123 instead of 0.123)
  defp parse_float(str) do
    trimmed = String.trim(str)

    normalized =
      case trimmed do
        "." <> _ -> "0" <> trimmed
        "-." <> rest -> "-0." <> rest
        _ -> trimmed
      end

    String.to_float(normalized)
  end

  @spec parse_tle(String.t(), String.t()) :: {:ok, TLE.t()} | {:error, String.t()}
  def parse_tle(longstr1, longstr2) do
    with :ok <- validate_ascii(longstr1, longstr2),
         line1 = clean_tle_line(longstr1, 69),
         line2 = clean_tle_line(longstr2, 69),
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
         :ok <- validate_line2_positions(line2) do
      validate_matching_satellite_numbers(line1, line2)
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
    fields = %{
      catalog_number: String.slice(line1, 2..6),
      classification: String.at(line1, 7) || "U",
      intldesg: String.trim_trailing(String.slice(line1, 9..16)),
      two_digit_year: String.slice(line1, 18..19) |> String.trim() |> String.to_integer(),
      epochdays: String.slice(line1, 20..31) |> parse_float(),
      ndot: parse_ndot(line1),
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

  defp parse_ndot(line1) do
    # ndot is in revolutions/day² but SGP4 expects radians/minute²
    # Conversion: rev/day² -> rad/min² = value * 2π * (1/1440)² 
    ndot_rev_per_day2 = String.slice(line1, 33..42) |> parse_float()
    ndot_rev_per_day2 * 2 * :math.pi() / (1440.0 * 1440.0)
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

    start_of_year_utc =
      DateTime.new!(Date.new!(epoch_year, 1, 1), Time.new!(0, 0, 0, 0), "Etc/UTC")

    epoch_with_days_utc = DateTime.add(start_of_year_utc, whole_days, :day)
    microseconds = round(fractional_day * @microseconds_per_day)
    DateTime.add(epoch_with_days_utc, microseconds, :microsecond)
  end


  @spec propagate_tle_to_datetime(TLE.t(), DateTime.t()) ::
          {:ok, TemeState.t()} | {:error, String.t()}
  def propagate_tle_to_datetime(tle, datetime) do
    # Convert datetime to tuple format for the NIF
    datetime_tuple =
      {{datetime.year, datetime.month, datetime.day},
       {datetime.hour, datetime.minute, datetime.second, elem(datetime.microsecond, 0)}}

    # Extract two-digit year and epochdays from TLE
    two_digit_year = String.slice(tle.line1, 18..19) |> String.to_integer()
    epochdays = String.slice(tle.line1, 20..31) |> parse_float()
    
    # Create a map with all TLE elements for the NIF
    tle_map = %{
      catalog_number: tle.catalog_number,
      bstar: tle.bstar,
      mean_motion_dot: tle.mean_motion_dot,
      mean_motion_double_dot: tle.mean_motion_double_dot,
      eccentricity: tle.eccentricity,
      arg_perigee_deg: tle.arg_perigee_deg,
      inclination_deg: tle.inclination_deg,
      mean_anomaly_deg: tle.mean_anomaly_deg,
      mean_motion: tle.mean_motion,
      raan_deg: tle.raan_deg,
      epochyr: two_digit_year,
      epochdays: epochdays
    }
    
    # Use the new NIF that bypasses twoline2rv entirely
    case SGP4NIF.propagate_with_elements(tle_map, datetime_tuple) do
      {:ok, {position, velocity}} ->
        {:ok,
         %TemeState{
           # Already in km from C++
           position: position,
           # Already in km/s from C++
           velocity: velocity
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec propagate_to_geodetic(TLE.t(), DateTime.t(), keyword()) ::
          {:ok, %{latitude: float(), longitude: float(), altitude_km: float()}}
          | {:error, String.t()}
  def propagate_to_geodetic(%TLE{} = tle, %DateTime{} = datetime, opts \\ []) do
    alias Sgp4Ex.CoordinateSystems

    case propagate_tle_to_datetime(tle, datetime) do
      {:ok, teme_state} ->
        CoordinateSystems.teme_to_geodetic(teme_state, datetime, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end
end