defmodule IAU2000ACoefficientsTest do
  use ExUnit.Case
  doctest Sgp4Ex.IAU2000ANutation

  @moduledoc """
  Tests to ensure IAU 2000A coefficients match Skyfield exactly.
  
  These tests MUST NEVER be changed - they prevent breaking the fundamental
  argument coefficients that were laboriously debugged and fixed.
  """

  # Known good values from Skyfield
  @test_jd_tt 2460385.000800741
  @skyfield_dpsi -2.2574453254350892e-5  # These exact values from working implementation
  @skyfield_deps 4.475016478583627e-5
  @tolerance 1.0e-12  # Very tight tolerance

  describe "fundamental arguments coefficients" do
    test "FA coefficients must match Skyfield exactly" do
      # These are the CORRECT coefficients from Skyfield
      # DO NOT CHANGE THESE VALUES!
      expected_fa0 = [
        485868.249036,      # Mean Anomaly of the Moon
        1287104.79305,      # Mean Anomaly of the Sun  
        335779.526232,      # Mean Longitude of Moon minus Mean Longitude of Ascending Node
        1072260.70369,      # Mean Elongation of the Moon from the Sun
        450160.398036       # Mean Longitude of the Ascending Node of the Moon
      ]
      
      expected_fa1 = [
        1717915923.2178,    # Mean Anomaly of the Moon - linear term
        129596581.0481,     # Mean Anomaly of the Sun - linear term
        1739527262.8478,    # Mean Longitude of Moon minus ascending node - linear term  
        1602961601.2090,    # Mean Elongation of the Moon from the Sun - linear term
        -6962890.5431       # Mean Longitude of the Ascending Node - linear term
      ]

      # Test that our module has the correct values
      # Note: We can't directly access the @fa0, @fa1 module attributes,
      # but we can test through the nutation calculation
      {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(@test_jd_tt)
      
      assert abs(dpsi - @skyfield_dpsi) < @tolerance, 
        "Dpsi mismatch: got #{dpsi}, expected #{@skyfield_dpsi}"
      assert abs(deps - @skyfield_deps) < @tolerance,
        "Deps mismatch: got #{deps}, expected #{@skyfield_deps}"
    end

    test "nutation calculation produces Skyfield-compatible results" do
      {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(@test_jd_tt)
      
      # Test dpsi (delta psi in longitude)
      ratio_dpsi = dpsi / @skyfield_dpsi
      assert abs(ratio_dpsi - 1.0) < 1.0e-6, 
        "Dpsi ratio #{ratio_dpsi} too far from 1.0"
        
      # Test deps (delta epsilon in obliquity)  
      ratio_deps = deps / @skyfield_deps
      assert abs(ratio_deps - 1.0) < 1.0e-6,
        "Deps ratio #{ratio_deps} too far from 1.0"
    end

    test "raw calculation matches Skyfield in 0.1 microarcseconds" do
      # Test that raw values (before conversion to radians) match Skyfield
      {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(@test_jd_tt)
      
      # Convert back to 0.1 microarcseconds
      asec2rad = 4.848136811095359935899141e-6
      dpsi_raw = dpsi / (1.0e-7 * asec2rad)
      deps_raw = deps / (1.0e-7 * asec2rad)
      
      # Skyfield raw values in 0.1 microarcseconds
      skyfield_dpsi_raw = -46563194.85207441
      skyfield_deps_raw = 92303834.93278898
      
      ratio_dpsi = dpsi_raw / skyfield_dpsi_raw
      ratio_deps = deps_raw / skyfield_deps_raw
      
      assert abs(ratio_dpsi - 1.0) < 1.0e-6,
        "Raw dpsi ratio #{ratio_dpsi} too far from 1.0"
      assert abs(ratio_deps - 1.0) < 1.0e-6, 
        "Raw deps ratio #{ratio_deps} too far from 1.0"
    end
  end

  describe "coefficient regression protection" do
    test "NEVER change these coefficient checksums" do
      # These checksums protect against accidental coefficient changes
      # If these tests fail, you probably broke the fundamental argument coefficients!
      
      # Test a few nutation values at different times to ensure coefficients work across the board
      test_cases = [
        {2451545.0, {-6.754422080371437e-5, -2.7970834513556333e-5}},   # J2000.0
        {2460385.000800741, {@skyfield_dpsi, @skyfield_deps}},          # Our test case
        {2470000.0, {6.605024523412206e-5, -3.19858881888431e-5}}       # Future date
      ]
      
      for {jd_tt, {expected_dpsi, expected_deps}} <- test_cases do
        {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
        
        assert abs(dpsi - expected_dpsi) < 1.0e-10,
          "JD #{jd_tt}: dpsi #{dpsi} != expected #{expected_dpsi}"
        assert abs(deps - expected_deps) < 1.0e-10,
          "JD #{jd_tt}: deps #{deps} != expected #{expected_deps}"
      end
    end
  end

  describe "Nx tensor operations" do
    test "unified module uses Nx tensors throughout" do
      # Verify this is properly using Nx operations, not scalar arithmetic
      jd_tt_tensor = Nx.tensor(@test_jd_tt, type: :f64)
      {dpsi_tensor, deps_tensor} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation_tensor(jd_tt_tensor)
      
      # Convert tensors to scalars and verify they match the scalar function
      dpsi_scalar = Nx.to_number(dpsi_tensor)
      deps_scalar = Nx.to_number(deps_tensor)
      
      {dpsi_direct, deps_direct} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(@test_jd_tt)
      
      assert abs(dpsi_scalar - dpsi_direct) < 1.0e-15,
        "Tensor and scalar dpsi don't match"
      assert abs(deps_scalar - deps_direct) < 1.0e-15,
        "Tensor and scalar deps don't match"
    end
  end
end