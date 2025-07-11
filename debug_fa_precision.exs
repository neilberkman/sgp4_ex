# Check fundamental arguments precision impact
jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0
t = (jd_tt - 2451545.0) / 36525.0

# Our fundamental arguments
our_fa = Sgp4Ex.IAU2000ANutation.fundamental_arguments(Nx.tensor(t, type: :f64))
our_fa_list = Nx.to_list(our_fa)

# Expected Skyfield values
expected_fa = [1.213214596930936, 1.225856087663708, 0.711022421912160, 1.118442507179634, -5.987642548353915]

IO.puts("Fundamental arguments precision check:")
IO.puts("Index | Our Value          | Expected           | Difference         | Diff (arcsec)")
IO.puts("------|--------------------|--------------------|--------------------|--------------")

total_error_impact = 0.0

Enum.with_index(our_fa_list) |> Enum.each(fn {our_val, i} ->
  expected_val = Enum.at(expected_fa, i)
  diff = our_val - expected_val
  diff_arcsec = diff * 206264.806247  # radians to arcseconds
  
  # Rough estimate of impact on longitude (very approximate)
  impact_estimate = abs(diff_arcsec) * 0.1  # rough scaling factor
  total_error_impact = total_error_impact + impact_estimate
  
  IO.puts("#{i}     | #{Float.round(our_val, 15)} | #{Float.round(expected_val, 15)} | #{Float.round(diff, 15)} | #{Float.round(diff_arcsec, 6)}")
end)

IO.puts("")
IO.puts("Estimated total longitude impact: #{Float.round(total_error_impact, 3)} arcseconds")
IO.puts("Our actual remaining error: 4.18 arcseconds")
IO.puts("Fundamental args might account for: #{Float.round(total_error_impact / 4.18 * 100, 1)}% of error")