#!/usr/bin/env elixir

{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(2460385.000800741)
IO.puts("Unified dpsi: #{dpsi}")
IO.puts("Unified deps: #{deps}")
IO.puts("")
IO.puts("Skyfield dpsi: -2.2574473900454788e-05")  
IO.puts("Skyfield deps: 4.47501619942924e-05")
IO.puts("")
IO.puts("Dpsi ratio: #{dpsi / -2.2574473900454788e-05}")
IO.puts("Deps ratio: #{deps / 4.47501619942924e-05}")