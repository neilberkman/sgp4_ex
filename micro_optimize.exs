#!/usr/bin/env elixir

# MISSION: BEAT PYTHON BY OPTIMIZING EVERY MICROSECOND! 🔥

# Force CPU-only
Application.put_env(:exla, :default_client, :host)

# Test data
line1 = "1 48808U 21047A   23086.46230110 -.00000330  00000-0  00000-0 0  5890"
line2 = "2 48808   0.2330 283.2669 0003886 229.5666 331.3824  1.00276212  6769"

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
test_time = DateTime.add(tle.epoch, 75 * 60, :second)

# Warm up
Enum.each(1..10, fn _ -> 
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true)
end)

defmodule MicroBench do
  def time_microseconds(name, func) do
    times = Enum.map(1..200, fn _ ->
      start = System.monotonic_time(:microsecond)
      result = func.()
      elapsed = System.monotonic_time(:microsecond) - start
      {elapsed, result}
    end)
    
    avg_us = times |> Enum.map(&elem(&1, 0)) |> Enum.sum() |> Kernel./(200)
    min_us = times |> Enum.map(&elem(&1, 0)) |> Enum.min()
    result = times |> List.first() |> elem(1)
    
    IO.puts("#{name}: #{Float.round(avg_us, 1)}μs avg, #{min_us}μs min")
    result
  end
end

IO.puts("🔬 MICRO-OPTIMIZATION HUNT - EVERY MICROSECOND COUNTS!")
IO.puts("Target: Beat Python's 367μs per satellite\n")

# Test each component in MICROSECONDS
tsince = (DateTime.diff(test_time, tle.epoch) / 60.0)
teme_result = SGP4NIF.propagate_tle(line1, line2, tsince)
{:ok, {{x, y, z}, {vx, vy, vz}}} = teme_result
teme_position = {x, y, z}

IO.puts("🎯 COMPONENT BREAKDOWN:")

MicroBench.time_microseconds("SGP4 NIF", fn ->
  SGP4NIF.propagate_tle(line1, line2, tsince)
end)

MicroBench.time_microseconds("DateTime->JD", fn ->
  Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_time)
end)

jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_time)
jd_tt = jd_ut1 + 69.19318735599518 / 86400.0

MicroBench.time_microseconds("GAST calculation", fn ->
  Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
end)

MicroBench.time_microseconds("TEME->ECEF", fn ->
  Sgp4Ex.CoordinateSystems.teme_to_ecef(teme_position, test_time, use_iau2000a: true)
end)

ecef_pos = Sgp4Ex.CoordinateSystems.teme_to_ecef(teme_position, test_time, use_iau2000a: true)

MicroBench.time_microseconds("ECEF->Geodetic", fn ->
  Sgp4Ex.CoordinateSystems.ecef_to_geodetic(ecef_pos)
end)

IO.puts("\n🎯 FULL PIPELINE:")
_result = MicroBench.time_microseconds("COMPLETE propagate_to_geodetic", fn ->
  Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true) |> elem(1)
end)

# Get the actual timing from a clean run
times = Enum.map(1..100, fn _ ->
  start = System.monotonic_time(:microsecond)
  {:ok, _} = Sgp4Ex.propagate_to_geodetic(tle, test_time, use_iau2000a: true)
  System.monotonic_time(:microsecond) - start
end)

avg_us = Enum.sum(times) / length(times)
min_us = Enum.min(times)

IO.puts("\n🏁 FINAL RESULTS:")
IO.puts("Elixir avg: #{Float.round(avg_us, 1)}μs")
IO.puts("Elixir min: #{min_us}μs")
IO.puts("Python:     367μs")

if avg_us < 367 do
  speedup = 367.0 / avg_us
  IO.puts("\n🎉🎉🎉 WE ABSOLUTELY CRUSHED PYTHON by #{Float.round(speedup, 2)}x! 🚀💥🔥")
  IO.puts("🏆 ELIXIR WINS! SUCK IT PYTHON!")
else
  gap = avg_us - 367
  IO.puts("\n❌ Still #{Float.round(gap, 1)}μs behind Python")
end

if min_us < 367 do
  best_speedup = 367.0 / min_us
  IO.puts("🔥 Best run: #{Float.round(best_speedup, 2)}x faster than Python!")
end