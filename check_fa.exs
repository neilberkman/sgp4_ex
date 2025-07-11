jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0
t = (jd_tt - 2451545.0) / 36525.0
fund_args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(Nx.tensor(t, type: :f64))
args_list = Nx.to_list(fund_args)
IO.puts("Our fundamental arguments:")
Enum.with_index(args_list) |> Enum.each(fn {val, i} -> 
  IO.puts("FA[#{i}]: #{val}")
end)