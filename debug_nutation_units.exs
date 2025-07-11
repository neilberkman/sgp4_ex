jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0

# Get our nutation values in radians
{dpsi_rad, deps_rad} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

# Convert back to microarcseconds to compare with Skyfield
asec2rad = 4.84813681109535984270e-06
dpsi_micro = dpsi_rad / (1.0e-6 * asec2rad)
deps_micro = deps_rad / (1.0e-6 * asec2rad)

IO.puts("Our nutation (converted to microarcsec):")
IO.puts("  dpsi: #{dpsi_micro} microarcsec")
IO.puts("  deps: #{deps_micro} microarcsec")

IO.puts("")
IO.puts("Expected from Skyfield:")
IO.puts("  dpsi: -46563194.85207441 microarcsec")
IO.puts("  deps: 92303834.93278898 microarcsec")

IO.puts("")
IO.puts("Differences:")
IO.puts("  dpsi diff: #{dpsi_micro - (-46563194.85207441)}")
IO.puts("  deps diff: #{deps_micro - 92303834.93278898}")