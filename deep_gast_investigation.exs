#!/usr/bin/env elixir

# DEEP INVESTIGATION: Why the FUCK is GAST off by 275ms?!

Application.put_env(:exla, :default_client, :host)

test_datetime = ~U[2024-03-15 12:00:00Z]
# Use precise JD values from test to match Skyfield exactly
jd_ut1 = 2460384.999999894
jd_tt = 2460385.000800741

# Skyfield reference values from our test
skyfield_gast_hours = 23.572220420489195
skyfield_gmst_hours = 23.572220416610136

IO.puts("🔍 DEEP GAST INVESTIGATION - NO STONE UNTURNED!")
IO.puts("Test datetime: #{test_datetime}")
IO.puts("JD_UT1: #{jd_ut1}")
IO.puts("JD_TT: #{jd_tt}")

# STEP 1: Check our GMST vs Skyfield
our_gmst = Sgp4Ex.IAU2000ANutation.gmst(jd_ut1, jd_tt)
gmst_diff_hours = our_gmst - skyfield_gmst_hours
gmst_diff_ms = gmst_diff_hours * 3600 * 1000

IO.puts("\n🕐 GMST ANALYSIS:")
IO.puts("  Our GMST:      #{our_gmst} hours")
IO.puts("  Skyfield GMST: #{skyfield_gmst_hours} hours") 
IO.puts("  GMST diff:     #{gmst_diff_hours} hours")
IO.puts("  GMST diff:     #{gmst_diff_ms} ms")

# STEP 2: Check our equation of equinoxes
our_eq_eq_rad = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)
our_eq_eq_hours = our_eq_eq_rad * 12.0 / :math.pi()

# Expected from test file (main + complementary)
skyfield_eq_eq_main = -2.071217015388278e-5
skyfield_eq_eq_complementary = 3.879058773358243e-09
skyfield_eq_eq_total = skyfield_eq_eq_main + skyfield_eq_eq_complementary
skyfield_eq_eq_hours = skyfield_eq_eq_total * 12.0 / :math.pi()

eq_eq_diff_hours = our_eq_eq_hours - skyfield_eq_eq_hours
eq_eq_diff_ms = eq_eq_diff_hours * 3600 * 1000

IO.puts("\n⚖️ EQUATION OF EQUINOXES ANALYSIS:")
IO.puts("  Our eq_eq (rad):    #{our_eq_eq_rad}")
IO.puts("  Our eq_eq (hours):  #{our_eq_eq_hours}")
IO.puts("  Skyfield (rad):     #{skyfield_eq_eq_total}")
IO.puts("  Skyfield (hours):   #{skyfield_eq_eq_hours}")
IO.puts("  eq_eq diff:         #{eq_eq_diff_hours} hours")
IO.puts("  eq_eq diff:         #{eq_eq_diff_ms} ms")

# STEP 3: Manual GAST calculation
manual_gast = our_gmst + our_eq_eq_hours
our_gast = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)

IO.puts("\n🧮 GAST ASSEMBLY:")
IO.puts("  GMST + eq_eq:  #{manual_gast} hours")
IO.puts("  Our GAST():    #{our_gast} hours")
IO.puts("  Skyfield GAST: #{skyfield_gast_hours} hours")
IO.puts("  Assembly match: #{abs(manual_gast - our_gast) < 0.000000000001}")

total_gast_diff = our_gast - skyfield_gast_hours
total_gast_diff_ms = total_gast_diff * 3600 * 1000

IO.puts("\n📊 TOTAL GAST ERROR:")
IO.puts("  Total GAST diff: #{total_gast_diff} hours")
IO.puts("  Total GAST diff: #{total_gast_diff_ms} ms")

# STEP 4: Error breakdown
IO.puts("\n🔬 ERROR BREAKDOWN:")
IO.puts("  GMST error:  #{Float.round(gmst_diff_ms, 3)} ms")
IO.puts("  eq_eq error: #{Float.round(eq_eq_diff_ms, 3)} ms")
IO.puts("  Total error: #{Float.round(total_gast_diff_ms, 3)} ms")
IO.puts("  Sum check:   #{Float.round(gmst_diff_ms + eq_eq_diff_ms, 3)} ms")

error_match = abs((gmst_diff_ms + eq_eq_diff_ms) - total_gast_diff_ms) < 0.001
IO.puts("  Errors add up: #{error_match}")

# STEP 5: Dig into GMST calculation details
IO.puts("\n🔍 GMST DEEP DIVE:")

# Earth rotation angle
era = Sgp4Ex.IAU2000ANutation.earth_rotation_angle(jd_ut1)
IO.puts("  Earth rotation angle: #{era}")

# Time since J2000
t = (jd_tt - 2451545.0) / 36525.0
IO.puts("  Centuries since J2000: #{t}")

# GMST components from our implementation
theta = era
st_arcsec = 0.014506 + 4612.156534 * t + 1.3915817 * t * t + (-0.00000044) * t * t * t + (-0.000029956) * t * t * t * t + (-0.0000000368) * t * t * t * t * t
st_hours = st_arcsec / 54000.0

manual_gmst = :math.fmod(st_hours + theta * 24.0, 24.0)

IO.puts("  ST component: #{st_hours} hours")
IO.puts("  ERA component: #{theta * 24.0} hours") 
IO.puts("  Manual GMST: #{manual_gmst} hours")
IO.puts("  Our GMST(): #{our_gmst} hours")
IO.puts("  GMST internal match: #{abs(manual_gmst - our_gmst) < 0.000000000001}")

IO.puts("\n🎯 ROOT CAUSE ANALYSIS:")
cond do
  abs(gmst_diff_ms) > 100 ->
    IO.puts("❌ GMST calculation is the primary culprit!")
    IO.puts("   Need to investigate GMST polynomial or ERA calculation")
  abs(eq_eq_diff_ms) > 100 ->
    IO.puts("❌ Equation of equinoxes is the primary culprit!")
    IO.puts("   Need to investigate nutation or obliquity calculation")
  true ->
    IO.puts("🤔 Both contribute - need to fix both components")
end