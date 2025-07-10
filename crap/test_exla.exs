#!/usr/bin/env elixir

# Test EXLA functionality
IO.puts("Testing EXLA...")

# Set EXLA as the default backend
Application.put_env(:nx, :default_backend, EXLA.Backend)

# List available platforms
IO.puts("\nAvailable platforms:")
platforms = EXLA.Client.get_supported_platforms()
IO.inspect(platforms)

# Get default client name
IO.puts("\nDefault client name: #{EXLA.Client.default_name()}")

# Get the host client
IO.puts("\nGetting host client...")
client = EXLA.Client.fetch!(EXLA.Client.default_name())
IO.puts("Client info:")
IO.puts("  Name: #{inspect(client.name)}")
IO.puts("  Platform: #{inspect(client.platform)}")
IO.puts("  Device count: #{client.device_count}")
IO.puts("  Default device ID: #{client.default_device_id}")

# Simple computation test
IO.puts("\nTesting simple computation...")
a = Nx.tensor([1, 2, 3], backend: EXLA.Backend)
b = Nx.tensor([4, 5, 6], backend: EXLA.Backend)
c = Nx.add(a, b)
IO.puts("a = #{inspect(Nx.to_list(a))}")
IO.puts("b = #{inspect(Nx.to_list(b))}")
IO.puts("a + b = #{inspect(Nx.to_list(c))}")

# Matrix multiplication test
IO.puts("\nTesting matrix multiplication...")
x = Nx.tensor([[1.0, 2.0], [3.0, 4.0]], backend: EXLA.Backend)
y = Nx.tensor([[5.0, 6.0], [7.0, 8.0]], backend: EXLA.Backend)
z = Nx.dot(x, y)
IO.puts("x = #{inspect(Nx.to_list(x))}")
IO.puts("y = #{inspect(Nx.to_list(y))}")
IO.puts("x · y = #{inspect(Nx.to_list(z))}")

# Test device placement
IO.puts("\nTesting device placement...")
tensor = Nx.tensor([1, 2, 3], backend: EXLA.Backend)
IO.puts("Tensor created with EXLA backend")
IO.inspect(tensor)

IO.puts("\nEXLA is working correctly on CPU!")