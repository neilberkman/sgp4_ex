#!/usr/bin/env elixir

# Start the application
Application.ensure_all_started(:sgp4_ex)

# Check the shapes of coefficient matrices
arg_mult = Sgp4Ex.IAU2000ACoefficients.lunisolar_arg_multipliers()
IO.puts("Lunisolar arg multipliers shape: #{inspect(Nx.shape(arg_mult))}")

# Check fundamental arguments shape
fa0 = Sgp4Ex.IAU2000ACoefficients.fa0()
IO.puts("FA0 shape: #{inspect(Nx.shape(fa0))}")

# Test fundamental arguments calculation
t_tensor = Nx.tensor(0.5, type: :f64)
args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(t_tensor)
IO.puts("Fundamental arguments shape: #{inspect(Nx.shape(args))}")
IO.puts("Fundamental arguments size: #{Nx.size(args)}")

# Check if it's 14 elements as expected
IO.puts("Fundamental args values: #{inspect(Nx.to_list(args))}")