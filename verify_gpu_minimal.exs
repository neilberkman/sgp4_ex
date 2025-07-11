#!/usr/bin/env mix run

# Minimal GPU verification - no SGP4 lib, just pure Nx/EXLA

IO.puts("🔥 MINIMAL GPU VERIFICATION")
IO.puts("=" |> String.duplicate(50))

# Check what we actually have
IO.puts("1️⃣ CHECKING EXLA COMPILATION...")
try do
  # Try to load EXLA and see what platforms are available
  Application.ensure_all_started(:exla)
  
  # Check EXLA compilation info
  IO.puts("✅ EXLA loaded successfully")
  
  # Try to create both CPU and GPU clients
  IO.puts("\n2️⃣ TESTING CPU CLIENT...")
  try do
    Application.put_env(:exla, :clients, host: [platform: :host])
    Application.put_env(:exla, :default_client, :host)
    Nx.default_backend(EXLA.Backend)
    
    cpu_tensor = Nx.tensor([1.0, 2.0, 3.0], type: :f64)
    cpu_result = Nx.multiply(cpu_tensor, 2.0)
    IO.puts("✅ CPU client works: #{inspect(cpu_result)}")
  rescue
    e -> IO.puts("❌ CPU client failed: #{inspect(e)}")
  end
  
  IO.puts("\n3️⃣ TESTING GPU CLIENT...")
  try do
    # Try different GPU configurations
    gpu_configs = [
      [cuda: [platform: :cuda]],
      [gpu: [platform: :gpu]], 
      [cuda: [platform: :gpu]]
    ]
    
    gpu_worked = false
    for config <- gpu_configs do
      try do
        Application.put_env(:exla, :clients, config)
        Application.put_env(:exla, :default_client, config |> hd() |> elem(0))
        Nx.default_backend(EXLA.Backend)
        
        gpu_tensor = Nx.tensor([1.0, 2.0, 3.0], type: :f64)
        gpu_result = Nx.multiply(gpu_tensor, 2.0)
        IO.puts("✅ GPU client works with #{inspect(config)}: #{inspect(gpu_result)}")
        gpu_worked = true
      rescue
        e -> IO.puts("❌ GPU config #{inspect(config)} failed: #{Exception.message(e)}")
      end
    end
    
    if not gpu_worked do
      IO.puts("❌ NO GPU CONFIGURATIONS WORKED")
    end
    
  rescue
    e -> IO.puts("❌ GPU testing failed: #{inspect(e)}")
  end
  
  IO.puts("\n4️⃣ CHECKING SYSTEM CUDA...")
  # Check if CUDA is available at system level
  {nvcc_output, nvcc_exit} = System.cmd("nvcc", ["--version"], stderr_to_stdout: true)
  if nvcc_exit == 0 do
    IO.puts("✅ NVCC found:")
    IO.puts(String.slice(nvcc_output, 0, 200))
  else
    IO.puts("❌ NVCC not found: #{nvcc_output}")
  end
  
  {nvidia_smi_output, nvidia_exit} = System.cmd("nvidia-smi", [], stderr_to_stdout: true)
  if nvidia_exit == 0 do
    IO.puts("✅ nvidia-smi found:")
    IO.puts(String.slice(nvidia_smi_output, 0, 300))
  else
    IO.puts("❌ nvidia-smi not found: #{nvidia_smi_output}")
  end
  
rescue
  e -> IO.puts("❌ EXLA failed to load: #{inspect(e)}")
end