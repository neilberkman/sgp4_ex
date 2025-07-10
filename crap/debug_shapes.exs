#!/usr/bin/env elixir

Application.ensure_all_started(:sgp4_ex)

# Let's understand the shapes
IO.puts("=== Shape debugging ===")

# Check arg multipliers
arg_mult = Sgp4Ex.IAU2000ACoefficients.lunisolar_arg_multipliers()
IO.puts("Lunisolar arg_mult shape: #{inspect(Nx.shape(arg_mult))}")

# The shape should be {1365, 5} - 1365 terms, each with 5 multipliers
# But we're getting {678, 5}

# Let's check the length of the raw data
{:module, module, _binary, _} = Code.ensure_loaded(Sgp4Ex.IAU2000ACoefficients)
{:ok, {_module, [{_, bin}]}} = :beam_lib.chunks(module, [:abstract_code])
{:ok, forms} = :erl_parse.parse_exprs(bin)

# Actually, let's check it a simpler way
raw_mult = Sgp4Ex.IAU2000ACoefficients.lunisolar_arg_multipliers() |> Nx.to_list()
IO.puts("Raw multipliers length: #{length(raw_mult)}")

# Check fundamental args
t = 0.5
t_tensor = Nx.tensor(t, type: :f64)
fund_args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(t_tensor)
IO.puts("Fundamental args shape: #{inspect(Nx.shape(fund_args))}")
IO.puts("Fundamental args: #{inspect(Nx.to_list(fund_args))}")

# The issue might be that we need 14 fundamental arguments, not 5
# Let's check the CPU version's fundamental_arguments more carefully