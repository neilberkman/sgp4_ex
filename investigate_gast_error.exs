#!/usr/bin/env elixir

# INVESTIGATE: Where exactly did we break GAST accuracy?

# Force CPU-only
Application.put_env(:exla, :default_client, :host)

IO.puts("🔍 INVESTIGATING GAST ERROR - Step by step breakdown")

# Use the EXACT test case from our component tests
test_datetime = ~U[2024-03-15 12:00:00Z]

# Skyfield reference values
skyfield_gast_hours = 23.572220420489195
skyfield_gmst_hours = 23.572220416610136
skyfield_eq_eq_hours = 3.879058773358244e-09
skyfield_dpsi = -0.00022574473900454788
skyfield_deps = 0.00044750161994292403
skyfield_mean_obliquity = 0.40903764357780753

IO.puts("Test datetime: #{test_datetime}")

# Calculate Julian dates
jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_datetime)
jd_tt = jd_ut1 + 69.184 / 86400.0

IO.puts("\n📅 JULIAN DATES:")
IO.puts("  JD_UT1: #{jd_ut1}")
IO.puts("  JD_TT:  #{jd_tt}")

# Step 1: Test nutation calculation 
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

IO.puts("\n🧮 STEP 1 - NUTATION:")
IO.puts("  Our dpsi:      #{dpsi}")
IO.puts("  Skyfield dpsi: #{skyfield_dpsi}")
IO.puts("  Error:         #{abs(dpsi - skyfield_dpsi)} rad")

IO.puts("  Our deps:      #{deps}")
IO.puts("  Skyfield deps: #{skyfield_deps}")
IO.puts("  Error:         #{abs(deps - skyfield_deps)} rad")

# Step 2: Test mean obliquity
mean_obl = Sgp4Ex.IAU2000ANutation.mean_obliquity(jd_tt)

IO.puts("\n🌍 STEP 2 - MEAN OBLIQUITY:")
IO.puts("  Our obliquity:      #{mean_obl}")
IO.puts("  Skyfield obliquity: #{skyfield_mean_obliquity}")
IO.puts("  Error:              #{abs(mean_obl - skyfield_mean_obliquity)} rad")

# Step 3: Test equation of equinoxes
eq_eq_rad = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)
eq_eq_hours = eq_eq_rad * 12.0 / :math.pi()

IO.puts("\n⚖️ STEP 3 - EQUATION OF EQUINOXES:")
IO.puts("  Our eq_eq (rad):    #{eq_eq_rad}")
IO.puts("  Our eq_eq (hours):  #{eq_eq_hours}")
IO.puts("  Skyfield (hours):   #{skyfield_eq_eq_hours}")
IO.puts("  Error (hours):      #{abs(eq_eq_hours - skyfield_eq_eq_hours)}")

# Step 4: Test GMST calculation
gmst_hours = Sgp4Ex.IAU2000ANutation.gmst(jd_ut1, jd_tt)

IO.puts("\n🕐 STEP 4 - GMST:")
IO.puts("  Our GMST:      #{gmst_hours} hours")
IO.puts("  Skyfield GMST: #{skyfield_gmst_hours} hours")
IO.puts("  Error:         #{abs(gmst_hours - skyfield_gmst_hours)} hours")
IO.puts("  Error (ms):    #{abs(gmst_hours - skyfield_gmst_hours) * 3600 * 1000} ms")

# Step 5: Test full GAST calculation
gast_hours = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)

IO.puts("\n🕐 STEP 5 - FULL GAST:")
IO.puts("  Our GAST:      #{gast_hours} hours")
IO.puts("  Skyfield GAST: #{skyfield_gast_hours} hours")
IO.puts("  Error:         #{abs(gast_hours - skyfield_gast_hours)} hours")
IO.puts("  Error (ms):    #{abs(gast_hours - skyfield_gast_hours) * 3600 * 1000} ms")

# Manual calculation check: GAST = GMST + equation of equinoxes
manual_gast = gmst_hours + eq_eq_hours

IO.puts("\n🔧 MANUAL VERIFICATION:")
IO.puts("  GMST + eq_eq = #{manual_gast} hours")
IO.puts("  Our GAST:    #{gast_hours} hours")
IO.puts("  Match?       #{abs(manual_gast - gast_hours) < 0.000000000001}")

IO.puts("\n🚨 ERROR ANALYSIS:")
gmst_error_ms = abs(gmst_hours - skyfield_gmst_hours) * 3600 * 1000
eq_eq_error_ms = abs(eq_eq_hours - skyfield_eq_eq_hours) * 3600 * 1000
total_error_ms = abs(gast_hours - skyfield_gast_hours) * 3600 * 1000

IO.puts("  GMST error:   #{Float.round(gmst_error_ms, 6)} ms")
IO.puts("  eq_eq error:  #{Float.round(eq_eq_error_ms, 6)} ms")
IO.puts("  Total error:  #{Float.round(total_error_ms, 6)} ms")

cond do
  gmst_error_ms > 100 ->
    IO.puts("\n❌ GMST CALCULATION IS THE CULPRIT!")
  eq_eq_error_ms > 100 ->
    IO.puts("\n❌ EQUATION OF EQUINOXES IS THE CULPRIT!")
  true ->
    IO.puts("\n🤔 ERROR IS SMALL COMPONENTS ADDING UP...")
end