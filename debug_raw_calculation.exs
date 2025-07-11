#!/usr/bin/env elixir

# Debug the raw tensor calculation before units conversion

jd_tt = 2460385.000800741
t = (jd_tt - 2451545.0) / 36525.0

IO.puts("=== RAW CALCULATION DEBUG ===")
IO.puts("JD_TT: #{jd_tt}")
IO.puts("T: #{t}")

# Get the tensor result before radians conversion
jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
{dpsi_tensor, deps_tensor} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation_tensor(jd_tt_tensor)

# This gives us the result AFTER 1e-7 * @asec2rad conversion
# To get raw 0.1 microarcseconds, we need to undo both conversions
asec2rad = 4.848136811095359935899141e-6
dpsi_raw = Nx.to_number(dpsi_tensor) / (1.0e-7 * asec2rad)
deps_raw = Nx.to_number(deps_tensor) / (1.0e-7 * asec2rad)

IO.puts("")
IO.puts("=== RAW TENSOR RESULTS (0.1 microarcseconds) ===")
IO.puts("My raw dpsi: #{dpsi_raw}")
IO.puts("My raw deps: #{deps_raw}")
IO.puts("")
IO.puts("=== SKYFIELD RAW RESULTS (0.1 microarcseconds) ===")
IO.puts("Skyfield raw dpsi: -46563194.85207441")
IO.puts("Skyfield raw deps: 92303834.93278898")
IO.puts("")
IO.puts("=== COMPARISON ===")
IO.puts("Dpsi ratio: #{dpsi_raw / -46563194.85207441}")
IO.puts("Deps ratio: #{deps_raw / 92303834.93278898}")