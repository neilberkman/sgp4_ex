#!/usr/bin/env elixir

# Test the fundamental arguments calculation after fixing coefficients

jd_tt = 2460385.000800741
t = (jd_tt - 2451545.0) / 36525.0

IO.puts("=== TESTING FIXED FUNDAMENTAL ARGUMENTS ===")
IO.puts("JD_TT: #{jd_tt}")
IO.puts("T: #{t}")

# Test if module compiles with new coefficients
try do
  Code.require_file("lib/sgp4_ex/iau2000a_nutation.ex")
  IO.puts("✓ Module compiled successfully")
rescue
  e -> 
    IO.puts("✗ Module compilation failed: #{inspect(e)}")
    System.halt(1)
end

# Test fundamental arguments calculation
jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
t_tensor = (jd_tt_tensor - 2451545.0) / 36525.0

# This should now give the correct fundamental arguments
fund_args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(t_tensor)
fa0 = Nx.to_number(fund_args[0])

IO.puts("")
IO.puts("=== FUNDAMENTAL ARGUMENTS COMPARISON ===")
IO.puts("My FA[0]: #{fa0}")
IO.puts("Expected from Skyfield: 1.2132145969309356")
IO.puts("Ratio: #{fa0 / 1.2132145969309356}")
IO.puts("Difference: #{abs(fa0 - 1.2132145969309356)}")

if abs(fa0 - 1.2132145969309356) < 1.0e-10 do
  IO.puts("✓ FUNDAMENTAL ARGUMENTS MATCH SKYFIELD!")
else
  IO.puts("✗ Fundamental arguments still wrong")
end

# Test full nutation calculation
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

IO.puts("")
IO.puts("=== NUTATION CALCULATION ===")
IO.puts("My dpsi: #{dpsi}")
IO.puts("My deps: #{deps}")
IO.puts("Expected dpsi: #{-2.26e-5}")
IO.puts("Expected deps: #{4.48e-5}")
IO.puts("Dpsi ratio: #{dpsi / (-2.26e-5)}")
IO.puts("Deps ratio: #{deps / (4.48e-5)}")