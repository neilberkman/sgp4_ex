#!/usr/bin/env elixir

# Test the GPU tensor operations to debug shape error
jd_ut1 = 2460384.999999894
jd_tt = 2460385.000800741

IO.puts("Testing GPU nutation...")

try do
  # Use the correct arity - gast_gpu/4 with default fractions
  result = Sgp4Ex.IAU2000ANutationGPU.gast_gpu(jd_ut1, jd_tt, 0.0, 0.0)
  IO.puts("GPU GAST result: #{result}")
rescue
  e in ArgumentError ->
    IO.puts("ArgumentError: #{e.message}")
    IO.puts("Stack trace:")
    IO.puts(Exception.format_stacktrace(__STACKTRACE__))
  e ->
    IO.puts("Other error: #{inspect(e)}")
    IO.puts("Stack trace:")
    IO.puts(Exception.format_stacktrace(__STACKTRACE__))
end