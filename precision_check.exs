#!/usr/bin/env elixir

# PRECISION CHECK: How close are we to 100% at each level?

Application.put_env(:exla, :default_client, :host)

test_datetime = ~U[2024-03-15 12:00:00Z]

# Use precise JD values from test to match Skyfield exactly
jd_ut1 = 2460384.999999894
jd_tt = 2460385.000800741

# Skyfield reference values
skyfield_l = 1.213214596930936
skyfield_l_prime = 1.225856087663708
skyfield_f = 0.711022421912160
skyfield_d = 1.118442507179634
skyfield_omega = -5.987642548353915

skyfield_dpsi = -0.00022574473900454788
skyfield_deps = 0.00044750161994292403
skyfield_mean_obliquity = 0.40903764357780753
skyfield_eq_eq_rad = -0.00002071217015388278 + 0.000000000003879058773358243
skyfield_gast_hours = 23.57214131204937

IO.puts("🔬 PRECISION CHECK - How close to 100% are we?")
IO.puts(String.duplicate("=", 60))

# Level 1: Julian Date Conversion
our_jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_datetime)
our_jd_tt = our_jd_ut1 + 69.184 / 86400.0

jd_ut1_diff = abs(our_jd_ut1 - jd_ut1)
jd_tt_diff = abs(our_jd_tt - jd_tt)

IO.puts("\n📅 LEVEL 1: Julian Date Conversion")
IO.puts("  JD_UT1 error: #{jd_ut1_diff} days (#{jd_ut1_diff * 86400 * 1000} ms)")
IO.puts("  JD_TT error:  #{jd_tt_diff} days (#{jd_tt_diff * 86400 * 1000} ms)")
if jd_ut1_diff < 0.000000000000001 and jd_tt_diff < 0.000000000000001 do
  IO.puts("  ✅ 100% PERFECT")
else
  IO.puts("  📊 #{100 - (jd_ut1_diff + jd_tt_diff) * 1000000000000}% accurate")
end

# Level 2: Fundamental Arguments
t = (jd_tt - 2451545.0) / 36525.0
fund_args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(Nx.tensor(t, type: :f64))
args_list = Nx.to_list(fund_args)

l_diff = abs(Enum.at(args_list, 0) - skyfield_l)
l_prime_diff = abs(Enum.at(args_list, 1) - skyfield_l_prime)
f_diff = abs(Enum.at(args_list, 2) - skyfield_f)
d_diff = abs(Enum.at(args_list, 3) - skyfield_d)
omega_diff = abs(Enum.at(args_list, 4) - skyfield_omega)

max_fund_diff = Enum.max([l_diff, l_prime_diff, f_diff, d_diff, omega_diff])

IO.puts("\n🌙 LEVEL 2: Fundamental Arguments")
IO.puts("  l (Moon) error:     #{l_diff} rad (#{l_diff * 180 / :math.pi() * 3600} arcsec)")
IO.puts("  l' (Sun) error:     #{l_prime_diff} rad (#{l_prime_diff * 180 / :math.pi() * 3600} arcsec)")
IO.puts("  F error:            #{f_diff} rad (#{f_diff * 180 / :math.pi() * 3600} arcsec)")
IO.puts("  D error:            #{d_diff} rad (#{d_diff * 180 / :math.pi() * 3600} arcsec)")
IO.puts("  Omega error:        #{omega_diff} rad (#{omega_diff * 180 / :math.pi() * 3600} arcsec)")
if max_fund_diff < 0.000000000000001 do
  IO.puts("  ✅ 100% PERFECT")
else
  relative_error = max_fund_diff / :math.pi() * 100
  IO.puts("  📊 #{100 - relative_error}% accurate")
end

# Level 3: Nutation
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

dpsi_diff = abs(dpsi - skyfield_dpsi)
deps_diff = abs(deps - skyfield_deps)

IO.puts("\n🔄 LEVEL 3: Nutation (1431 terms)")
IO.puts("  dpsi error: #{dpsi_diff} rad (#{dpsi_diff * 180 / :math.pi() * 3600 * 1000000} microarcsec)")
IO.puts("  deps error: #{deps_diff} rad (#{deps_diff * 180 / :math.pi() * 3600 * 1000000} microarcsec)")
if dpsi_diff < 0.000000000000001 and deps_diff < 0.000000000000001 do
  IO.puts("  ✅ 100% PERFECT")
else
  nutation_accuracy = 100 - (dpsi_diff + deps_diff) / (abs(skyfield_dpsi) + abs(skyfield_deps)) * 100
  IO.puts("  📊 #{Float.round(nutation_accuracy, 10)}% accurate")
end

# Level 4: Mean Obliquity
mean_obl = Sgp4Ex.IAU2000ANutation.mean_obliquity(jd_tt)
obl_diff = abs(mean_obl - skyfield_mean_obliquity)

IO.puts("\n🌍 LEVEL 4: Mean Obliquity")
IO.puts("  Error: #{obl_diff} rad (#{obl_diff * 180 / :math.pi() * 3600 * 1000000} microarcsec)")
if obl_diff < 0.000000000000001 do
  IO.puts("  ✅ 100% PERFECT")
else
  obl_accuracy = 100 - obl_diff / skyfield_mean_obliquity * 100
  IO.puts("  📊 #{Float.round(obl_accuracy, 12)}% accurate")
end

# Level 5: Equation of Equinoxes
eq_eq_rad = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)
eq_eq_diff = abs(eq_eq_rad - skyfield_eq_eq_rad)

IO.puts("\n⚖️ LEVEL 5: Equation of Equinoxes")
IO.puts("  Error: #{eq_eq_diff} rad (#{eq_eq_diff * 180 / :math.pi() * 3600 * 1000000} microarcsec)")
if eq_eq_diff < 0.000000000000001 do
  IO.puts("  ✅ 100% PERFECT")
else
  eq_eq_accuracy = 100 - eq_eq_diff / abs(skyfield_eq_eq_rad) * 100
  IO.puts("  📊 #{Float.round(eq_eq_accuracy, 8)}% accurate")
end

# Level 6: GAST
gast_hours = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
gast_diff = abs(gast_hours - skyfield_gast_hours)

IO.puts("\n🕐 LEVEL 6: Greenwich Apparent Sidereal Time")
IO.puts("  Error: #{gast_diff} hours (#{gast_diff * 3600 * 1000} ms)")
if gast_diff < 0.000000000000001 do
  IO.puts("  ✅ 100% PERFECT")
else
  gast_accuracy = 100 - gast_diff / skyfield_gast_hours * 100
  IO.puts("  📊 #{Float.round(gast_accuracy, 12)}% accurate")
end

IO.puts("\n\n")
IO.puts("🏆 SUMMARY:")
IO.puts("   Which levels achieve 100% perfection?")
perfect_levels = []
perfect_levels = if jd_ut1_diff < 0.000000000000001 and jd_tt_diff < 0.000000000000001, do: perfect_levels ++ ["Level 1"], else: perfect_levels
perfect_levels = if max_fund_diff < 0.000000000000001, do: perfect_levels ++ ["Level 2"], else: perfect_levels
perfect_levels = if dpsi_diff < 0.000000000000001 and deps_diff < 0.000000000000001, do: perfect_levels ++ ["Level 3"], else: perfect_levels
perfect_levels = if obl_diff < 0.000000000000001, do: perfect_levels ++ ["Level 4"], else: perfect_levels
perfect_levels = if eq_eq_diff < 0.000000000000001, do: perfect_levels ++ ["Level 5"], else: perfect_levels
perfect_levels = if gast_diff < 0.000000000000001, do: perfect_levels ++ ["Level 6"], else: perfect_levels

if length(perfect_levels) > 0 do
  IO.puts("   ✅ 100% PERFECT: #{Enum.join(perfect_levels, ", ")}")
else
  IO.puts("   📊 All levels have minor floating-point precision differences")
end