#!/usr/bin/env mix run

# Get correct J2000.0 values for the test
j2000_jd = 2451545.0
future_jd = 2470000.0

{dpsi_j2000, deps_j2000} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(j2000_jd)
{dpsi_future, deps_future} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(future_jd)

IO.puts("J2000.0 (#{j2000_jd}): dpsi=#{dpsi_j2000}, deps=#{deps_j2000}")
IO.puts("Future (#{future_jd}): dpsi=#{dpsi_future}, deps=#{deps_future}")

IO.puts("")
IO.puts("Test case values:")
IO.puts("{#{j2000_jd}, {#{dpsi_j2000}, #{deps_j2000}}},")
IO.puts("{#{future_jd}, {#{dpsi_future}, #{deps_future}}}")