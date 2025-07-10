#!/usr/bin/env elixir

Application.ensure_all_started(:sgp4_ex)

# Let's test with the CPU version first
jd_tt = 2460384.0
t = (jd_tt - 2_451_545.0) / 36525.0

# Get fundamental arguments
fund_args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(Nx.tensor(t, type: :f64))
IO.puts("CPU Fundamental arguments shape: #{inspect(Nx.shape(fund_args))}")
IO.puts("CPU Fundamental arguments: #{inspect(Nx.to_list(fund_args))}")

# Now let's see what happens with the matrix multiplication
arg_mult = Sgp4Ex.IAU2000ACoefficients.lunisolar_arg_multipliers()
IO.puts("\nArg multipliers shape: #{inspect(Nx.shape(arg_mult))}")

# Try the dot product
try do
  result = Nx.dot(arg_mult, fund_args)
  IO.puts("Dot product successful! Result shape: #{inspect(Nx.shape(result))}")
catch
  e -> IO.puts("Dot product failed: #{inspect(e)}")
end