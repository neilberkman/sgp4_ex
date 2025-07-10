#!/usr/bin/env elixir

Application.ensure_all_started(:sgp4_ex)

# Check lunisolar terms
lunisolar_mult = Sgp4Ex.IAU2000ACoefficients.lunisolar_arg_multipliers()
lunisolar_lon = Sgp4Ex.IAU2000ACoefficients.lunisolar_longitude_coefficients()
lunisolar_obl = Sgp4Ex.IAU2000ACoefficients.lunisolar_obliquity_coefficients()

IO.puts("Lunisolar arg multipliers shape: #{inspect(Nx.shape(lunisolar_mult))}")
IO.puts("Lunisolar longitude coeffs shape: #{inspect(Nx.shape(lunisolar_lon))}")
IO.puts("Lunisolar obliquity coeffs shape: #{inspect(Nx.shape(lunisolar_obl))}")

# The issue is 678 * 2 = 1356, which is close to 1365
# Maybe the data is split or partially loaded?