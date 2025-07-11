#!/usr/bin/env mix run

# Check GPU status and force GPU backend

IO.puts("🔍 CHECKING GPU STATUS")
IO.puts("=" |> String.duplicate(50))

# Check available backends
IO.puts("Current Nx default backend:")
current_backend = Nx.default_backend()
IO.puts("Default: #{inspect(current_backend)}")

# Try to use GPU backend explicitly
try do
  IO.puts("\n🚀 ATTEMPTING TO FORCE GPU BACKEND...")
  
  # Force GPU/CUDA backend
  Application.put_env(:exla, :clients, cuda: [platform: :cuda])
  Application.put_env(:exla, :default_client, :cuda)
  Nx.default_backend(EXLA.Backend)
  
  IO.puts("✅ GPU backend configuration set")
  
  # Test a simple tensor operation to see which backend is used
  test_tensor = Nx.tensor([1.0, 2.0, 3.0], type: :f64)
  result = Nx.multiply(test_tensor, 2.0)
  
  IO.puts("\n🧪 TESTING TENSOR OPERATION:")
  IO.puts("Input: #{inspect(test_tensor)}")
  IO.puts("Result: #{inspect(result)}")
  
  # Test nutation calculation
  IO.puts("\n🧪 TESTING NUTATION ON GPU:")
  jd_tt = 2460385.000800741
  start_time = :os.system_time(:microsecond)
  {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
  end_time = :os.system_time(:microsecond)
  duration = end_time - start_time
  
  IO.puts("Nutation result: dpsi=#{dpsi}, deps=#{deps}")
  IO.puts("Duration: #{duration}μs")
  
rescue
  e -> 
    IO.puts("❌ GPU backend failed: #{inspect(e)}")
    IO.puts("Falling back to CPU...")
    
    # Fall back to CPU
    Application.put_env(:exla, :clients, host: [platform: :host])
    Application.put_env(:exla, :default_client, :host)
    Nx.default_backend(EXLA.Backend)
    
    IO.puts("✅ CPU backend fallback set")
end