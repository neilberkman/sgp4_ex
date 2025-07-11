#!/usr/bin/env mix run

# SIMPLE REQUIREMENTS VERIFICATION

IO.puts("🔍 REQUIREMENTS VERIFICATION")
IO.puts("=" |> String.duplicate(50))

# Test data
test_jd_tt = 2460385.000800741
expected_dpsi = -2.2574453254350892e-5
expected_deps = 4.475016478583627e-5

pass_count = 0
total_tests = 7

# Test 1: Only one nutation module exists
IO.puts("\n1️⃣ UNIFIED MODULE: Only one nutation file")
nutation_files = File.ls!("lib/sgp4_ex") |> Enum.filter(&String.contains?(&1, "nutation"))
if nutation_files == ["iau2000a_nutation.ex"] do
  IO.puts("   ✅ PASS: Single unified module")
  pass_count = pass_count + 1
else
  IO.puts("   ❌ FAIL: Multiple files: #{inspect(nutation_files)}")
end

# Test 2: Uses Nx.Defn
IO.puts("\n2️⃣ NX TENSORS: Uses Nx.Defn operations")
content = File.read!("lib/sgp4_ex/iau2000a_nutation.ex")
if String.contains?(content, "import Nx.Defn") and String.contains?(content, "defn ") do
  IO.puts("   ✅ PASS: Uses Nx.Defn for tensor operations")  
  pass_count = pass_count + 1
else
  IO.puts("   ❌ FAIL: Missing Nx.Defn usage")
end

# Test 3: No hardcoded backends
IO.puts("\n3️⃣ AUTO BACKEND: No hardcoded CPU/GPU selection")
bad_patterns = ["EXLA", "default_client", "set_default"]
bad_found = bad_patterns |> Enum.filter(&String.contains?(content, &1))
if bad_found == [] do
  IO.puts("   ✅ PASS: No hardcoded backend selection")
  pass_count = pass_count + 1
else
  IO.puts("   ❌ FAIL: Found hardcoded patterns: #{inspect(bad_found)}")
end

# Test 4: Precompiled module attributes
IO.puts("\n4️⃣ MODULE ATTRS: Uses precompiled @fa0, @fa1, etc.")
fa_count = content |> String.split("\n") |> Enum.count(&String.match?(&1, ~r/@fa\d/))
if fa_count >= 4 do
  IO.puts("   ✅ PASS: Found #{fa_count} @fa module attributes")
  pass_count = pass_count + 1
else
  IO.puts("   ❌ FAIL: Only #{fa_count} @fa attributes found")
end

# Test 5: Skyfield accuracy
IO.puts("\n5️⃣ ACCURACY: Matches Skyfield (>99.999%)")
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(test_jd_tt)
dpsi_accuracy = (1.0 - abs(dpsi - expected_dpsi) / abs(expected_dpsi)) * 100
deps_accuracy = (1.0 - abs(deps - expected_deps) / abs(expected_deps)) * 100
min_accuracy = min(dpsi_accuracy, deps_accuracy)
if min_accuracy > 99.999 do
  IO.puts("   ✅ PASS: #{Float.round(min_accuracy, 5)}% accuracy")
  pass_count = pass_count + 1
else
  IO.puts("   ❌ FAIL: Only #{Float.round(min_accuracy, 5)}% accuracy")
end

# Test 6: No GPU-specific calls in coordinate systems
IO.puts("\n6️⃣ NO GPU CALLS: Coordinate systems use unified module")
coord_content = File.read!("lib/coordinate_systems.ex")
gpu_calls = coord_content 
            |> String.split("\n")
            |> Enum.filter(&(String.contains?(&1, "GPU") or String.contains?(&1, "_gpu")))
            |> Enum.reject(&String.contains?(&1, "#"))  # Ignore comments
if gpu_calls == [] do
  IO.puts("   ✅ PASS: No GPU-specific function calls")
  pass_count = pass_count + 1
else
  IO.puts("   ❌ FAIL: Found GPU calls: #{inspect(gpu_calls)}")
end

# Test 7: Protection tests exist and pass
IO.puts("\n7️⃣ PROTECTED TESTS: Coefficient protection tests pass")
{_output, exit_code} = System.cmd("mix", ["test", "test/iau2000a_coefficients_test.exs", "--quiet"], 
                                  stderr_to_stdout: true)
if exit_code == 0 do
  IO.puts("   ✅ PASS: Coefficient protection tests pass")
  pass_count = pass_count + 1
else
  IO.puts("   ❌ FAIL: Coefficient tests failed")
end

# Final result
IO.puts("\n" <> "=" |> String.duplicate(50))
IO.puts("🎯 RESULT: #{pass_count}/#{total_tests} requirements verified")

if pass_count == total_tests do
  IO.puts("🎉 ALL REQUIREMENTS MET - READY FOR PERFORMANCE!")
else
  IO.puts("⚠️  #{total_tests - pass_count} FAILURES - MUST FIX FIRST")
end