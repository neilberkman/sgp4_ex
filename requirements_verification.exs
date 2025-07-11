#!/usr/bin/env mix run

# COMPREHENSIVE REQUIREMENTS VERIFICATION
# This script ACTUALLY tests every requirement we claimed to have met

IO.puts("🔍 REQUIREMENTS VERIFICATION CHECKLIST")
IO.puts("=" |> String.duplicate(80))
IO.puts("")

# Test data
test_jd_tt = 2460385.000800741
tle_line1 = "1 25544U 98067A   24074.54761985  .00019515  00000+0  35063-3 0  9997"
tle_line2 = "2 25544  51.6410 299.5237 0005417  72.1189  36.3479 15.49802661443442"
test_datetime = ~U[2024-03-15 12:00:00Z]

# Expected Skyfield values
expected_dpsi = -2.2574453254350892e-5
expected_deps = 4.475016478583627e-5

# Results tracking  
results = Agent.start_link(fn -> %{
  unified_module: false,
  nx_tensors: false,
  cpu_gpu_auto: false,
  precompiled_attrs: false,
  skyfield_accuracy: false,
  no_gpu_versions: false,
  tensor_operations: false,
  protected_tests: false
} end)
{:ok, results_agent} = results

IO.puts("📋 REQUIREMENT 1: Truly unified nutation module (no separate CPU/GPU versions)")
try do
  # Check that there's only ONE nutation module
  nutation_files = File.ls!("lib/sgp4_ex") 
                   |> Enum.filter(&String.contains?(&1, "nutation"))
  
  if length(nutation_files) == 1 and hd(nutation_files) == "iau2000a_nutation.ex" do
    IO.puts("  ✅ Only one nutation file: #{inspect(nutation_files)}")
    
    # Verify no "gpu" references in the module
    content = File.read!("lib/sgp4_ex/iau2000a_nutation.ex")
    gpu_references = content 
                    |> String.downcase() 
                    |> String.split("\n")
                    |> Enum.with_index(1)
                    |> Enum.filter(fn {line, _} -> String.contains?(line, "gpu") end)
    
    if gpu_references == [] do
      IO.puts("  ✅ No 'gpu' references found in unified module")
      results = Map.put(results, :unified_module, true)
    else
      IO.puts("  ❌ Found GPU references: #{inspect(gpu_references)}")
    end
  else
    IO.puts("  ❌ Multiple nutation files found: #{inspect(nutation_files)}")
  end
rescue
  e -> IO.puts("  ❌ Error checking files: #{inspect(e)}")
end

IO.puts("")
IO.puts("📋 REQUIREMENT 2: Uses Nx tensors with precompiled module attributes")
try do
  content = File.read!("lib/sgp4_ex/iau2000a_nutation.ex")
  
  # Check for @fa0, @fa1, etc. module attributes
  fa_attrs = content 
             |> String.split("\n")
             |> Enum.filter(&String.contains?(&1, "@fa"))
             |> length()
  
  # Check for Nx.tensor usage in module attributes
  nx_tensor_attrs = content
                   |> String.split("\n") 
                   |> Enum.filter(&(String.contains?(&1, "@") and String.contains?(&1, "Nx.tensor")))
                   |> length()
  
  if fa_attrs >= 4 and nx_tensor_attrs >= 4 do
    IO.puts("  ✅ Found #{fa_attrs} @fa attributes with #{nx_tensor_attrs} Nx.tensor declarations")
    results = Map.put(results, :precompiled_attrs, true)
  else
    IO.puts("  ❌ Insufficient precompiled tensor attributes")
  end
  
  # Check for import Nx.Defn
  if String.contains?(content, "import Nx.Defn") do
    IO.puts("  ✅ Uses Nx.Defn for tensor operations")
    results = Map.put(results, :nx_tensors, true)
  else
    IO.puts("  ❌ Missing 'import Nx.Defn'")
  end
rescue
  e -> IO.puts("  ❌ Error checking Nx usage: #{inspect(e)}")
end

IO.puts("")
IO.puts("📋 REQUIREMENT 3: Automatic CPU/GPU backend selection (no hardcoded backends)")
try do
  content = File.read!("lib/sgp4_ex/iau2000a_nutation.ex")
  
  # Check for defn functions (which auto-select backend)
  defn_count = content
               |> String.split("\n")
               |> Enum.filter(&String.match?(&1, ~r/^\s*defn\s+/))
               |> length()
  
  # Check for any hardcoded EXLA/GPU/CPU backend forcing
  bad_patterns = [
    "EXLA",
    ":gpu",
    ":cpu", 
    "Backend",
    "default_client",
    "set_default"
  ]
  
  bad_refs = bad_patterns
             |> Enum.filter(&String.contains?(content, &1))
  
  if defn_count > 0 and bad_refs == [] do
    IO.puts("  ✅ Found #{defn_count} defn functions with no hardcoded backends")
    results = Map.put(results, :cpu_gpu_auto, true)
  else
    IO.puts("  ❌ Found hardcoded backend references: #{inspect(bad_refs)}")
  end
rescue
  e -> IO.puts("  ❌ Error checking backend selection: #{inspect(e)}")
end

IO.puts("")
IO.puts("📋 REQUIREMENT 4: Skyfield-compatible accuracy (>99.999%)")
try do
  {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(test_jd_tt)
  
  dpsi_error = abs(dpsi - expected_dpsi) / abs(expected_dpsi)
  deps_error = abs(deps - expected_deps) / abs(expected_deps)
  
  dpsi_accuracy = (1.0 - dpsi_error) * 100
  deps_accuracy = (1.0 - deps_error) * 100
  
  min_accuracy = min(dpsi_accuracy, deps_accuracy)
  
  if min_accuracy > 99.999 do
    IO.puts("  ✅ Accuracy: dpsi #{Float.round(dpsi_accuracy, 6)}%, deps #{Float.round(deps_accuracy, 6)}%")
    results = Map.put(results, :skyfield_accuracy, true)
  else
    IO.puts("  ❌ Insufficient accuracy: #{Float.round(min_accuracy, 6)}%")
  end
rescue
  e -> IO.puts("  ❌ Error testing accuracy: #{inspect(e)}")
end

IO.puts("")
IO.puts("📋 REQUIREMENT 5: No separate GPU-specific function calls in coordinate systems")
try do
  content = File.read!("lib/coordinate_systems.ex")
  
  # Check for any calls to GPU-specific functions
  gpu_calls = content
              |> String.split("\n")
              |> Enum.with_index(1)
              |> Enum.filter(fn {line, _} -> 
                String.contains?(String.downcase(line), "gpu") or
                String.contains?(line, "IAU2000ANutationGPU") or
                String.contains?(line, "_gpu")
              end)
  
  if gpu_calls == [] do
    IO.puts("  ✅ No GPU-specific function calls in coordinate systems")
    results = Map.put(results, :no_gpu_versions, true)
  else
    IO.puts("  ❌ Found GPU-specific calls: #{inspect(gpu_calls)}")
  end
rescue
  e -> IO.puts("  ❌ Error checking coordinate systems: #{inspect(e)}")
end

IO.puts("")
IO.puts("📋 REQUIREMENT 6: Tensor operations work correctly")
try do
  # Test tensor vs scalar equivalence
  jd_tt_tensor = Nx.tensor(test_jd_tt, type: :f64)
  {dpsi_tensor, deps_tensor} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation_tensor(jd_tt_tensor)
  
  dpsi_from_tensor = Nx.to_number(dpsi_tensor)
  deps_from_tensor = Nx.to_number(deps_tensor)
  
  {dpsi_scalar, deps_scalar} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(test_jd_tt)
  
  tensor_scalar_match = abs(dpsi_from_tensor - dpsi_scalar) < 1.0e-15 and
                       abs(deps_from_tensor - deps_scalar) < 1.0e-15
  
  if tensor_scalar_match do
    IO.puts("  ✅ Tensor and scalar operations produce identical results")
    results = Map.put(results, :tensor_operations, true)
  else
    IO.puts("  ❌ Tensor/scalar mismatch: tensor(#{dpsi_from_tensor}, #{deps_from_tensor}) vs scalar(#{dpsi_scalar}, #{deps_scalar})")
  end
rescue
  e -> IO.puts("  ❌ Error testing tensor operations: #{inspect(e)}")
end

IO.puts("")
IO.puts("📋 REQUIREMENT 7: Comprehensive tests prevent coefficient breakage")
try do
  # Check that our protection test exists and passes
  {output, exit_code} = System.cmd("mix", ["test", "test/iau2000a_coefficients_test.exs", "--formatter", "ExUnit.CLIFormatter"], 
                                   stderr_to_stdout: true)
  
  if exit_code == 0 and String.contains?(output, "5 tests, 0 failures") do
    IO.puts("  ✅ Coefficient protection tests exist and pass")
    results = Map.put(results, :protected_tests, true)
  else
    IO.puts("  ❌ Coefficient tests failed or missing")
    IO.puts("  Output: #{String.slice(output, 0, 200)}")
  end
rescue
  e -> IO.puts("  ❌ Error running tests: #{inspect(e)}")
end

IO.puts("")
IO.puts("🎯 FINAL VERIFICATION RESULTS")
IO.puts("=" |> String.duplicate(80))

all_passed = Enum.all?(Map.values(results))

for {requirement, passed} <- results do
  status = if passed, do: "✅ PASS", else: "❌ FAIL"
  IO.puts("#{status} #{requirement}")
end

IO.puts("")
if all_passed do
  IO.puts("🎉 ALL REQUIREMENTS VERIFIED - READY FOR PERFORMANCE TESTING!")
else
  failed_count = results |> Map.values() |> Enum.count(&(!&1))
  IO.puts("⚠️  #{failed_count} REQUIREMENTS FAILED - MUST FIX BEFORE PROCEEDING")
end