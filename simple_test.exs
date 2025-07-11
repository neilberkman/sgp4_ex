#!/usr/bin/env mix run

# Simple test for fundamental arguments fix

jd_tt = 2460385.000800741

IO.puts("Testing fixed fundamental arguments...")

# Test fundamental arguments
t = (jd_tt - 2451545.0) / 36525.0
jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
t_tensor = Nx.divide(Nx.subtract(jd_tt_tensor, 2451545.0), 36525.0)

# Test fundamental arguments through the main function since fundamental_arguments is private
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

IO.puts("Testing through main nutation function...")

# Test full calculation
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
IO.puts("Dpsi: #{dpsi}")
IO.puts("Deps: #{deps}")

expected_dpsi = -0.0000226
expected_deps = 0.0000448
IO.puts("Dpsi match: #{abs(dpsi - expected_dpsi) < 0.000001}")
IO.puts("Deps match: #{abs(deps - expected_deps) < 0.000001}")