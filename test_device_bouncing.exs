#!/usr/bin/env mix run

# Test for CPU->GPU device bouncing during nutation calculation
IO.puts("🔍 DEVICE BOUNCING TEST")
IO.puts("=" |> String.duplicate(50))

# Force CUDA configuration
Application.put_env(:exla, :clients, cuda: [platform: :cuda])
Application.put_env(:exla, :default_client, :cuda)
Nx.default_backend(EXLA.Backend)

IO.puts("✅ Configured for CUDA")

# Test our nutation calculation step by step
jd_tt = 2460676.045302481

IO.puts("🧪 Testing tensor creation...")
jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
IO.puts("JD tensor device: #{inspect(jd_tt_tensor)}")

IO.puts("🧪 Testing nutation tensor calculation...")
start_time = :os.system_time(:microsecond)
{dpsi_tensor, deps_tensor} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation_tensor(jd_tt_tensor)
end_time = :os.system_time(:microsecond)

IO.puts("Dpsi tensor device: #{inspect(dpsi_tensor)}")
IO.puts("Deps tensor device: #{inspect(deps_tensor)}")
IO.puts("Tensor nutation time: #{end_time - start_time}μs")

IO.puts("🧪 Testing scalar conversion...")
start_time = :os.system_time(:microsecond)
{dpsi_scalar, deps_scalar} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
end_time = :os.system_time(:microsecond)

IO.puts("Dpsi scalar: #{dpsi_scalar}")
IO.puts("Deps scalar: #{deps_scalar}")
IO.puts("Scalar nutation time: #{end_time - start_time}μs")

IO.puts("🧪 Testing GAST calculation...")
jd_ut1 = jd_tt
start_time = :os.system_time(:microsecond)
gast = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
end_time = :os.system_time(:microsecond)

IO.puts("GAST: #{gast}")
IO.puts("GAST time: #{end_time - start_time}μs")

# Test if we can keep everything on tensors
IO.puts("🧪 Testing pure tensor GAST...")
jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
fraction_ut1_tensor = Nx.tensor(0.0, type: :f64)
fraction_tt_tensor = Nx.tensor(0.0, type: :f64)

start_time = :os.system_time(:microsecond)
gast_tensor = Sgp4Ex.IAU2000ANutation.gast_tensor(jd_ut1_tensor, jd_tt_tensor, fraction_ut1_tensor, fraction_tt_tensor)
end_time = :os.system_time(:microsecond)

IO.puts("GAST tensor device: #{inspect(gast_tensor)}")
IO.puts("Pure tensor GAST time: #{end_time - start_time}μs")

IO.puts("✅ Device bouncing test complete")