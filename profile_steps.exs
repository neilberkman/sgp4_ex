#!/usr/bin/env elixir

# Force CPU-only
Application.put_env(:exla, :clients, host: [platform: :host])
Application.put_env(:exla, :default_client, :host)
Nx.default_backend(EXLA.Backend)

# Test TLE
line1 = "1 48808U 21047A   23086.46230110 -.00000330  00000-0  00000-0 0  5890"
line2 = "2 48808   0.2330 283.2669 0003886 229.5666 331.3824  1.00276212  6769"

IO.puts("🔍 PROFILING EACH STEP\n")

# Warm up first
{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
test_time = DateTime.add(tle.epoch, 75 * 60, :second)
Enum.each(1..10, fn _ -> 
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true)
end)

defmodule ProfileStep do
  def time_step(name, func) do
    times = Enum.map(1..100, fn _ ->
      start = System.monotonic_time(:microsecond)
      result = func.()
      elapsed = System.monotonic_time(:microsecond) - start
      {elapsed / 1000.0, result}
    end)
    
    avg_time = times |> Enum.map(&elem(&1, 0)) |> Enum.sum() |> Kernel./(100)
    result = times |> List.first() |> elem(1)
    
    IO.puts("#{name}: #{Float.round(avg_time, 3)}ms avg")
    result
  end
end

# Step 1: TLE Parsing
tle = ProfileStep.time_step("1. TLE Parsing", fn ->
  Sgp4Ex.parse_tle(line1, line2) |> elem(1)
end)

# Step 2: SGP4 Propagation (NIF call)
tsince = (DateTime.diff(test_time, tle.epoch) / 60.0)
teme_result = ProfileStep.time_step("2. SGP4 NIF Call", fn ->
  SGP4NIF.propagate_tle(line1, line2, tsince)
end)

{:ok, {{x, y, z}, {vx, vy, vz}}} = teme_result
teme_position = {x, y, z}

# Step 3: DateTime to Julian Date
_jd_ut1 = ProfileStep.time_step("3. DateTime->JD", fn ->
  Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_time)
end)

# Step 4: GAST Calculation (includes nutation)
_gast_rad = ProfileStep.time_step("4. GAST Calculation", fn ->
  jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_time)
  jd_tt = jd_ut1 + 69.19318735599518 / 86400.0
  Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
end)

# Step 5: TEME to ECEF rotation
_ecef_pos = ProfileStep.time_step("5. TEME->ECEF", fn ->
  Sgp4Ex.CoordinateSystems.teme_to_ecef(teme_position, test_time, use_iau2000a: true)
end)

# Step 6: ECEF to Geodetic
_geodetic = ProfileStep.time_step("6. ECEF->Geodetic", fn ->
  ecef_test = Sgp4Ex.CoordinateSystems.teme_to_ecef(teme_position, test_time, use_iau2000a: true)
  Sgp4Ex.CoordinateSystems.ecef_to_geodetic(ecef_test)
end)

IO.puts("\n🎯 FULL PIPELINE:")
_full_time = ProfileStep.time_step("FULL propagate_to_geodetic", fn ->
  Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true) |> elem(1)
end)

IO.puts("\n📊 ANALYSIS:")
IO.puts("If steps were independent, sum would be ~#{Float.round(2.3 + 0.1 + 0.1 + 4.0 + 0.1 + 0.1, 1)}ms")
IO.puts("Actual full pipeline: probably much higher due to overhead")
IO.puts("\nPython does equivalent in ~0.03-0.14ms")