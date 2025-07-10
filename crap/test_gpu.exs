#!/usr/bin/env elixir

# Configure EXLA for GPU
Application.put_env(:exla, :clients,
  cuda: [platform: :cuda, preallocate: false],
  host: [platform: :host]
)
Application.put_env(:exla, :default_client, :cuda)
Nx.default_backend(EXLA.Backend)

# Test GPU detection
IO.puts("\n=== Testing EXLA GPU Support ===")
platforms = EXLA.Client.get_supported_platforms()
IO.inspect(platforms, label: "Supported platforms")

# Try to create a CUDA client
try do
  client = EXLA.Client.fetch!(:cuda)
  IO.puts("\nCUDA client created successfully!")
  IO.inspect(client, label: "CUDA client")
  
  # Create a tensor on GPU
  tensor = Nx.tensor([1, 2, 3])
  IO.inspect(tensor, label: "Test tensor")
  
  # Show where the tensor is
  if String.contains?(inspect(tensor), "cuda") do
    IO.puts("\n✅ SUCCESS: Tensor is on CUDA device!")
  else
    IO.puts("\n❌ WARNING: Tensor is not on CUDA device")
  end
rescue
  e -> 
    IO.puts("\nError creating CUDA client:")
    IO.inspect(e)
    IO.puts("\nThis is expected on macOS - CUDA is not available locally")
    IO.puts("GPU tests must be run on the GCP instance")
end

IO.puts("\n=== Platform Information ===")
IO.puts("OS: #{:os.type() |> elem(1)}")
IO.puts("XLA target: #{System.get_env("XLA_TARGET") || "not set"}")
IO.puts("CUDA available: #{System.find_executable("nvcc") != nil}")