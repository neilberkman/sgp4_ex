#!/usr/bin/env mix run

# Debug coefficient differences between CPU and GPU implementations

IO.puts("\n=== Debugging GPU vs CPU Coefficients ===\n")

# Get CPU coefficients from the module
fa0_cpu = Sgp4Ex.IAU2000ACoefficients.fa0() |> Nx.squeeze() |> Nx.to_list()
fa1_cpu = Sgp4Ex.IAU2000ACoefficients.fa1() |> Nx.squeeze() |> Nx.to_list()

IO.puts("CPU FA0 (first 5): #{inspect(Enum.take(fa0_cpu, 5))}")
IO.puts("CPU FA1 (first 5): #{inspect(Enum.take(fa1_cpu, 5))}")

# GPU hardcoded coefficients (from the GPU module)
fa0_gpu = [
  3.154384999847899,
  2.357551718265301,
  1.6280158027288272,
  5.198471222772339,
  2.182438624381695
]

fa1_gpu = [
  628_307_584_999.0,
  8_399_684.6073,
  8_433_463.1576,
  7_771_374.8964,
  -33.86238
]

IO.puts("GPU FA0: #{inspect(fa0_gpu)}")
IO.puts("GPU FA1: #{inspect(fa1_gpu)}")

# Compare differences
fa0_diffs = Enum.zip(Enum.take(fa0_cpu, 5), fa0_gpu) 
            |> Enum.map(fn {cpu, gpu} -> abs(cpu - gpu) end)

fa1_diffs = Enum.zip(Enum.take(fa1_cpu, 5), fa1_gpu) 
            |> Enum.map(fn {cpu, gpu} -> abs(cpu - gpu) end)

IO.puts("\nFA0 differences: #{inspect(fa0_diffs)}")
IO.puts("FA1 differences: #{inspect(fa1_diffs)}")

max_fa0_diff = Enum.max(fa0_diffs)
max_fa1_diff = Enum.max(fa1_diffs)

IO.puts("\nMax FA0 difference: #{max_fa0_diff}")
IO.puts("Max FA1 difference: #{max_fa1_diff}")

if max_fa0_diff > 1.0e-10 or max_fa1_diff > 1.0e-10 do
  IO.puts("\n❌ SIGNIFICANT COEFFICIENT DIFFERENCES!")
else
  IO.puts("\n✅ Coefficients match")
end