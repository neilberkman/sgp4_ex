#!/usr/bin/env mix run

# Core precision check - avoiding satellite array module
# Tests the fundamental coordinate transformation pipeline

import Sgp4Ex.CoordinateSystems
alias Sgp4Ex.IAU2000ANutation

# Test parameters
tle_line1 = "1 25544U 98067A   24074.54761985  .00019515  00000+0  35063-3 0  9997"
tle_line2 = "2 25544  51.6410 299.5237 0005417  72.1189  36.3479 15.49802661443442"
test_datetime = ~U[2024-03-15 12:00:00Z]

# Skyfield reference values
skyfield_lat = 14.430885155233963
skyfield_lon = -90.18151736026806
skyfield_alt = 418.0513200783848

IO.puts("🔬 CORE PRECISION CHECK - Level by Level")
IO.puts("=" |> String.duplicate(60))
IO.puts("")

# Level 1: Nutation calculation  
IO.puts("📅 LEVEL 1: IAU 2000A Nutation")
jd_ut1 = datetime_to_julian_date(test_datetime)
jd_tt = jd_ut1 + 69.19318735599518 / 86400.0

{dpsi, deps} = IAU2000ANutation.iau2000a_nutation(jd_tt)
skyfield_dpsi = -2.2574453254350892e-5
skyfield_deps = 4.475016478583627e-5

dpsi_error = abs(dpsi - skyfield_dpsi)
deps_error = abs(deps - skyfield_deps)
dpsi_accuracy = (1.0 - dpsi_error / abs(skyfield_dpsi)) * 100
deps_accuracy = (1.0 - deps_error / abs(skyfield_deps)) * 100

IO.puts("  Dpsi error: #{dpsi_error} (#{Float.round(dpsi_accuracy, 6)}% accurate)")
IO.puts("  Deps error: #{deps_error} (#{Float.round(deps_accuracy, 6)}% accurate)")
IO.puts("")

# Level 2: Mean obliquity
IO.puts("📅 LEVEL 2: Mean Obliquity")
mean_obl = IAU2000ANutation.mean_obliquity(jd_tt)
skyfield_mean_obl = 0.40905105670775464  # from Skyfield
mean_obl_error = abs(mean_obl - skyfield_mean_obl)
mean_obl_accuracy = (1.0 - mean_obl_error / skyfield_mean_obl) * 100
IO.puts("  Mean obliquity error: #{mean_obl_error} (#{Float.round(mean_obl_accuracy, 10)}% accurate)")
IO.puts("")

# Level 3: True obliquity
IO.puts("📅 LEVEL 3: True Obliquity")
true_obl = mean_obl + deps
skyfield_true_obl = 0.4090958365740281  # from Skyfield  
true_obl_error = abs(true_obl - skyfield_true_obl)
true_obl_accuracy = (1.0 - true_obl_error / skyfield_true_obl) * 100
IO.puts("  True obliquity error: #{true_obl_error} (#{Float.round(true_obl_accuracy, 10)}% accurate)")
IO.puts("")

# Level 4-6: Use GAST directly since it includes GMST + equation of equinoxes
IO.puts("📅 LEVEL 4-6: Greenwich Apparent Sidereal Time (includes GMST + Eq of Equinoxes)")
gast_hours = IAU2000ANutation.gast(jd_ut1, jd_tt)
skyfield_gast_hours = 23.57214131204937  # from Skyfield
gast_error = abs(gast_hours - skyfield_gast_hours)
gast_accuracy = (1.0 - gast_error / skyfield_gast_hours) * 100
IO.puts("  GAST error: #{gast_error} hours (#{Float.round(gast_accuracy, 10)}% accurate)")
IO.puts("")

# Level 7: SGP4 Propagation (using direct SGP4 call)
IO.puts("📅 LEVEL 7: SGP4 Propagation")
try do
  # Parse TLE and propagate
  tle = Sgp4Ex.TLE.parse_tle(tle_line1, tle_line2)
  satellite = Sgp4Ex.Satellite.from_tle(tle)
  
  # Calculate minutes since epoch
  epoch_datetime = tle.epoch
  time_diff_seconds = DateTime.diff(test_datetime, epoch_datetime, :second)
  minutes_since_epoch = time_diff_seconds / 60.0
  
  # Propagate
  case Sgp4Ex.Satellite.propagate(satellite, minutes_since_epoch) do
    {:ok, {pos_x, pos_y, pos_z, _vel_x, _vel_y, _vel_z}} ->
      IO.puts("  ✓ SGP4 propagation successful")
      IO.puts("  Position: (#{pos_x}, #{pos_y}, #{pos_z}) km")
      
      # Level 8: TEME to Geodetic conversion
      IO.puts("")
      IO.puts("📅 LEVEL 8: TEME to Geodetic Conversion")
      
      case teme_to_geodetic({pos_x, pos_y, pos_z}, test_datetime) do
        {:ok, %{latitude: lat, longitude: lon, altitude_km: alt}} ->
          lat_error = abs(lat - skyfield_lat)
          lon_error = abs(lon - skyfield_lon) 
          alt_error = abs(alt - skyfield_alt)
          
          lat_accuracy = (1.0 - lat_error / abs(skyfield_lat)) * 100
          lon_accuracy = (1.0 - lon_error / abs(skyfield_lon)) * 100
          alt_accuracy = (1.0 - alt_error / skyfield_alt) * 100
          
          IO.puts("  Latitude error: #{lat_error}° (#{Float.round(lat_accuracy, 6)}% accurate)")
          IO.puts("  Longitude error: #{lon_error}° (#{Float.round(lon_accuracy, 6)}% accurate)")
          IO.puts("  Altitude error: #{alt_error} km (#{Float.round(alt_accuracy, 6)}% accurate)")
          
        error ->
          IO.puts("  ✗ TEME to geodetic conversion failed: #{inspect(error)}")
      end
      
    {:error, reason} ->
      IO.puts("  ✗ SGP4 propagation failed: #{reason}")
  end
rescue
  e ->
    IO.puts("  ✗ SGP4 error: #{inspect(e)}")
end

IO.puts("")
IO.puts("🎯 SUMMARY")
IO.puts("=" |> String.duplicate(60))
IO.puts("Level 1 (Nutation): #{Float.round(min(dpsi_accuracy, deps_accuracy), 4)}% accurate")
IO.puts("Level 2 (Mean Obl): #{Float.round(mean_obl_accuracy, 4)}% accurate") 
IO.puts("Level 3 (True Obl): #{Float.round(true_obl_accuracy, 4)}% accurate")
IO.puts("Level 4-6 (GAST): #{Float.round(gast_accuracy, 4)}% accurate")