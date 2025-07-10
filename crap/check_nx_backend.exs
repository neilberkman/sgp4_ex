#!/usr/bin/env mix run

IO.puts("=== Nx Backend Configuration ===")
IO.puts("Default backend: #{inspect(Nx.default_backend())}")

# Test matrix multiplication performance
sizes = [100, 500, 1000]

Enum.each(sizes, fn size ->
  IO.puts("\n--- Matrix #{size}x#{size} Performance ---")
  
  # Create random matrices
  a = Nx.random_uniform({size, size}) |> Nx.as_type(:f64)
  b = Nx.random_uniform({size, size}) |> Nx.as_type(:f64)
  
  # Warm up
  _warmup = Nx.dot(a, b)
  
  # Time it
  {time_us, _result} = :timer.tc(fn ->
    Nx.dot(a, b)
  end)
  
  time_ms = time_us / 1000.0
  operations = 2 * size * size * size  # Approximate FLOPs
  gflops = operations / (time_us / 1_000_000) / 1_000_000_000
  
  IO.puts("Time: #{Float.round(time_ms, 2)} ms")
  IO.puts("Performance: #{Float.round(gflops, 1)} GFLOPS")
end)

IO.puts("\n=== Available Backends ===")
# Check what backends are available
IO.puts("Nx backends: #{inspect(Nx.Backend.available_backends())}")

IO.puts("\n=== EXLA Status ===")
try do
  if Code.ensure_loaded?(EXLA) do
    IO.puts("EXLA is available")
    # Try to use EXLA backend
    old_backend = Nx.default_backend()
    Nx.default_backend(EXLA.Backend)
    
    # Test with EXLA
    a = Nx.tensor([[1.0, 2.0], [3.0, 4.0]], type: :f64)
    b = Nx.tensor([[5.0, 6.0], [7.0, 8.0]], type: :f64)
    
    {time_us, result} = :timer.tc(fn ->
      Nx.dot(a, b)
    end)
    
    IO.puts("EXLA test successful: #{time_us} us")
    IO.puts("Result: #{inspect(result)}")
    
    # Restore backend
    Nx.default_backend(old_backend)
  else
    IO.puts("EXLA is not available")
  end
rescue
  e -> IO.puts("EXLA error: #{inspect(e)}")
end