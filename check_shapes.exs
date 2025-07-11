#!/usr/bin/env elixir

# Check tensor shapes for debugging
lunisolar_mult = Sgp4Ex.IAU2000ACoefficients.lunisolar_arg_multipliers()
IO.puts("Lunisolar arg multipliers shape: #{inspect(Nx.shape(lunisolar_mult))}")

lunisolar_lon = Sgp4Ex.IAU2000ACoefficients.lunisolar_longitude_coefficients()
IO.puts("Lunisolar lon coeffs shape: #{inspect(Nx.shape(lunisolar_lon))}")

lunisolar_obl = Sgp4Ex.IAU2000ACoefficients.lunisolar_obliquity_coefficients()
IO.puts("Lunisolar obl coeffs shape: #{inspect(Nx.shape(lunisolar_obl))}")

fa0 = Sgp4Ex.IAU2000ACoefficients.fa0()
IO.puts("FA0 shape: #{inspect(Nx.shape(fa0))}")

planetary_mult = Sgp4Ex.IAU2000ACoefficients.planetary_arg_multipliers()
IO.puts("Planetary arg multipliers shape: #{inspect(Nx.shape(planetary_mult))}")

planetary_lon = Sgp4Ex.IAU2000ACoefficients.planetary_longitude_coefficients()
IO.puts("Planetary lon coeffs shape: #{inspect(Nx.shape(planetary_lon))}")

planetary_obl = Sgp4Ex.IAU2000ACoefficients.planetary_obliquity_coefficients()
IO.puts("Planetary obl coeffs shape: #{inspect(Nx.shape(planetary_obl))}")