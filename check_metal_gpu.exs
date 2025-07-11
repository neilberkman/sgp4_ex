#!/usr/bin/env mix run

# Check for Metal GPU support on Apple Silicon

IO.puts("🍎 APPLE SILICON GPU CHECK (Metal)")
IO.puts("=" |> String.duplicate(50))

try do
  # Try Metal/GPU configurations for Apple Silicon
  metal_configs = [
    [metal: [platform: :metal]],
    [gpu: [platform: :metal]],
    [tpu: [platform: :tpu]],  # Sometimes TPU is used for Apple Neural Engine
    [accelerator: [platform: :accelerator]]
  ]
  
  IO.puts("Trying Metal/GPU configurations...")
  
  for config <- metal_configs do
    try do
      Application.put_env(:exla, :clients, config) 
      Application.put_env(:exla, :default_client, config |> hd() |> elem(0))
      Nx.default_backend(EXLA.Backend)
      
      test_tensor = Nx.tensor([1.0, 2.0, 3.0], type: :f64)
      result = Nx.multiply(test_tensor, 2.0)
      
      IO.puts("✅ #{inspect(config)} WORKS!")
      IO.puts("   Result: #{inspect(result)}")
      
      # Test nutation on this backend
      jd_tt = 2460385.000800741
      start = :os.system_time(:microsecond)
      {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
      duration = :os.system_time(:microsecond) - start
      
      IO.puts("   Nutation: dpsi=#{dpsi}, deps=#{deps}")
      IO.puts("   Duration: #{duration}μs")
      
    rescue
      e -> IO.puts("❌ #{inspect(config)}: #{Exception.message(e)}")
    end
  end
  
rescue
  e -> IO.puts("❌ Metal check failed: #{inspect(e)}")
end

IO.puts("\n🔍 Let's also check what EXLA actually reports as available:")
try do
  # This might give us more info about available backends
  Application.ensure_all_started(:exla)
  IO.puts("✅ EXLA started successfully")
rescue
  e -> IO.puts("❌ EXLA start failed: #{inspect(e)}")
end