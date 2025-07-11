# Debug GMST calculation vs Skyfield
jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0

# Our GMST calculation
our_gmst = Sgp4Ex.IAU2000ANutation.gmst(jd_ut1, jd_tt)

# Expected from Skyfield
expected_gmst = 23.572220416610136

IO.puts("GMST comparison:")
IO.puts("  Our GMST: #{our_gmst} hours")
IO.puts("  Expected: #{expected_gmst} hours")

gmst_diff_hours = our_gmst - expected_gmst
gmst_diff_arcsec = gmst_diff_hours * 15.0 * 3600.0  # hours -> degrees -> arcseconds

IO.puts("  Difference: #{gmst_diff_hours} hours")
IO.puts("  Difference: #{gmst_diff_arcsec} arcseconds")

IO.puts("")
IO.puts("Our remaining longitude error: 4.18 arcseconds")
IO.puts("GMST error accounts for: #{Float.round(abs(gmst_diff_arcsec) / 4.18 * 100, 1)}% of remaining error")

# Check ERA calculation separately
era_fraction = Sgp4Ex.IAU2000ANutation.earth_rotation_angle(jd_ut1)
era_hours = era_fraction * 24.0

IO.puts("")
IO.puts("Earth Rotation Angle check:")
IO.puts("  ERA: #{era_fraction} (fraction of day)")
IO.puts("  ERA: #{era_hours} hours")

# Check if ERA is the issue
# GMST = ERA + precession terms
# If ERA is wrong, GMST will be wrong