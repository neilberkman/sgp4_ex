#!/usr/bin/env elixir

{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(2460385.000800741)
skyfield_dpsi = -2.2574473900454788e-05
skyfield_deps = 4.47501619942924e-05

dpsi_error = abs(dpsi - skyfield_dpsi)
deps_error = abs(deps - skyfield_deps)

IO.puts("Dpsi error: #{dpsi_error} radians")
IO.puts("Deps error: #{deps_error} radians")
IO.puts("")
IO.puts("Dpsi error: #{dpsi_error / 4.84813681109536e-6} arcseconds")
IO.puts("Deps error: #{deps_error / 4.84813681109536e-6} arcseconds")
IO.puts("")
IO.puts("Dpsi error: #{dpsi_error / 4.84813681109536e-6 * 1000} milliarcseconds")
IO.puts("Deps error: #{deps_error / 4.84813681109536e-6 * 1000} milliarcseconds")