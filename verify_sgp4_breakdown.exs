#!/usr/bin/env mix run

# Breakdown of where the 60x slowdown vs Python is coming from

IO.puts("⚡ SGP4 PERFORMANCE BREAKDOWN")
IO.puts("=" |> String.duplicate(50))

# Same TLE as Python test
line1 = "1 25544U 98067A   24074.54761985  .00019515  00000+0  35063-3 0  9997"
line2 = "2 25544  51.6410 299.5237 0005417  72.1189  36.3479 15.49802661443442"
test_datetime = ~U[2024-03-15 12:00:00Z]

IO.puts("Target: Beat Python's 0.027ms per satellite")
IO.puts("Current Elixir: ~1.6ms per satellite (60x slower)")
IO.puts("")

# Step by step timing function
defmodule TimingHelper do
  def time_us(label, func) do
    # Warm up
    for _ <- 1..5, do: func.()
    
    # Time
    times = for _ <- 1..100 do
      start = :os.system_time(:microsecond)
      func.()
      :os.system_time(:microsecond) - start
    end
    
    avg = Enum.sum(times) / length(times)
    min_val = Enum.min(times)
    IO.puts("#{label}: #{Float.round(avg, 1)}μs avg, #{min_val}μs min")
    avg
  end
end

# Setup
{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
epoch_datetime = tle.epoch
time_diff_seconds = DateTime.diff(test_datetime, epoch_datetime, :second)
minutes_since_epoch = time_diff_seconds / 60.0

IO.puts("🔧 COMPONENT TIMING:")

# 1. Pure SGP4 propagation
sgp4_time = TimingHelper.time_us("1. SGP4 NIF only", fn ->
  {:ok, _teme_state} = Sgp4Ex.propagate_tle_to_epoch(tle, test_datetime)
end)

# 2. DateTime to Julian Date
jd_time = TimingHelper.time_us("2. DateTime->JD", fn ->
  Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_datetime)
end)

# 3. GAST calculation  
jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_datetime)
jd_tt = jd_ut1 + 69.19318735599518 / 86400.0
gast_time = TimingHelper.time_us("3. GAST calculation", fn ->
  Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
end)

# 4. TEME to ECEF rotation
{:ok, teme_state} = Sgp4Ex.propagate_tle_to_epoch(tle, test_datetime)
{x, y, z} = teme_state.position
gast_rad = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt) * 15.0 * :math.pi() / 180.0
teme_to_ecef_time = TimingHelper.time_us("4. TEME->ECEF rotation", fn ->
  cos_gast = :math.cos(gast_rad)
  sin_gast = :math.sin(gast_rad) 
  x_ecef = x * cos_gast + y * sin_gast
  y_ecef = -x * sin_gast + y * cos_gast
  z_ecef = z
  {x_ecef, y_ecef, z_ecef}
end)

# 5. ECEF to Geodetic
{x_ecef, y_ecef, z_ecef} = {x * :math.cos(gast_rad) + y * :math.sin(gast_rad), 
                           -x * :math.sin(gast_rad) + y * :math.cos(gast_rad), z}
ecef_to_geo_time = TimingHelper.time_us("5. ECEF->Geodetic", fn ->
  Sgp4Ex.CoordinateSystems.ecef_to_geodetic({x_ecef, y_ecef, z_ecef})
end)

# 6. Full pipeline
full_time = TimingHelper.time_us("6. FULL PIPELINE", fn ->
  Sgp4Ex.CoordinateSystems.teme_to_geodetic({x, y, z}, test_datetime)
end)

total_components = sgp4_time + jd_time + gast_time + teme_to_ecef_time + ecef_to_geo_time

IO.puts("")
IO.puts("📊 ANALYSIS:")
IO.puts("Components sum: #{Float.round(total_components, 1)}μs")
IO.puts("Full pipeline:  #{Float.round(full_time, 1)}μs")
IO.puts("Python target:  27μs")
IO.puts("")
IO.puts("🔍 BOTTLENECKS (biggest first):")

components = [
  {"GAST calculation", gast_time},
  {"TEME->ECEF rotation", teme_to_ecef_time}, 
  {"SGP4 NIF", sgp4_time},
  {"ECEF->Geodetic", ecef_to_geo_time},
  {"DateTime->JD", jd_time}
]

components
|> Enum.sort_by(&elem(&1, 1), :desc)
|> Enum.with_index(1)
|> Enum.each(fn {{name, time}, rank} ->
  percent = time / full_time * 100
  IO.puts("#{rank}. #{name}: #{Float.round(time, 1)}μs (#{Float.round(percent, 1)}%)")
end)

IO.puts("")
slowdown = full_time / 27
IO.puts("🎯 CURRENT SLOWDOWN: #{Float.round(slowdown, 1)}x vs Python")

if slowdown > 50 do
  IO.puts("❌ CRITICAL: 50+ times slower than Python")
  IO.puts("   The GAST calculation is the likely culprit")
  IO.puts("   Python probably uses much simpler/faster coordinate transformation")
else
  IO.puts("⚠️  Significant slowdown, but could be optimized")
end