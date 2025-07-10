IO.puts("=== CPU vs GPU Performance Test ===")

alias Sgp4Ex.IAU2000ANutationGPU

# Test parameters
jd_tt = 2460000.0
jd_ut1 = 2460000.0
jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)

# Test CPU performance
IO.puts("Testing CPU performance...")
Nx.default_backend({EXLA.Backend, client: :host})

# Warmup
_ = IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)

# CPU benchmark
{cpu_time_us, _} = :timer.tc(fn -> 
  IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)
end)
cpu_time_ms = cpu_time_us / 1000.0

IO.puts("CPU time: #{:io_lib.format("~.3f", [cpu_time_ms])}ms")

# Test GPU performance if available
if Code.ensure_loaded?(EXLA.Backend) do
  IO.puts("\nTesting GPU performance...")
  Nx.default_backend({EXLA.Backend, client: :cuda})
  
  # Warmup GPU
  _ = IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)
  
  # GPU benchmark
  {gpu_time_us, _} = :timer.tc(fn -> 
    IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)
  end)
  gpu_time_ms = gpu_time_us / 1000.0
  
  IO.puts("GPU time: #{:io_lib.format("~.3f", [gpu_time_ms])}ms")
  
  # Compare
  speedup = cpu_time_ms / gpu_time_ms
  IO.puts("\nComparison:")
  IO.puts("GPU speedup: #{:io_lib.format("~.2f", [speedup])}x")
  
  if speedup > 1.0 do
    IO.puts("✅ GPU is faster than CPU")
  else
    IO.puts("❌ CPU is faster than GPU")
  end
else
  IO.puts("GPU not available")
end