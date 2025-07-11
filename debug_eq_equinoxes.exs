#!/usr/bin/env elixir

# DEBUG: What should equation of equinoxes actually be?

Application.put_env(:exla, :default_client, :host)

test_datetime = ~U[2024-03-15 12:00:00Z]
jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_datetime)
jd_tt = jd_ut1 + 69.184 / 86400.0

# Calculate our components
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
epsilon = Sgp4Ex.IAU2000ANutation.mean_obliquity(jd_tt)
eq_eq_rad = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)

# Expected from test file
skyfield_main = -2.071217015388278e-5
skyfield_complementary = 3.879058773358243e-09
skyfield_total = skyfield_main + skyfield_complementary

IO.puts("🔍 EQUATION OF EQUINOXES DEBUG")
IO.puts("\n📊 OUR CALCULATION:")
IO.puts("  dpsi: #{dpsi}")
IO.puts("  epsilon: #{epsilon}")
IO.puts("  dpsi * cos(epsilon): #{dpsi * :math.cos(epsilon)}")
IO.puts("  Our eq_eq: #{eq_eq_rad}")

IO.puts("\n📊 SKYFIELD EXPECTED:")
IO.puts("  Main term: #{skyfield_main}")
IO.puts("  Complementary: #{skyfield_complementary}")
IO.puts("  Total: #{skyfield_total}")

IO.puts("\n📊 COMPARISON:")
IO.puts("  Our value: #{eq_eq_rad}")
IO.puts("  Expected: #{skyfield_total}")
IO.puts("  Difference: #{abs(eq_eq_rad - skyfield_total)}")
IO.puts("  Ratio: #{eq_eq_rad / skyfield_total}")

# Check if we're in the right ballpark
if abs(eq_eq_rad - skyfield_total) < 0.000001 do
  IO.puts("\n✅ CLOSE ENOUGH - Within microradians!")
else
  IO.puts("\n❌ STILL WAY OFF!")
end