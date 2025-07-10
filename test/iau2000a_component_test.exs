defmodule Sgp4Ex.IAU2000AComponentTest do
  use ExUnit.Case

  @moduledoc """
  Component-level tests for IAU 2000A implementation.
  Tests each calculation level against Skyfield reference values.
  """

  # Test datetime - same as our failing case
  @test_datetime ~U[2024-03-15 12:00:00Z]

  describe "IAU 2000A component breakdown" do
    test "Level 1: Julian date conversion matches Skyfield" do
      # We'll get Skyfield reference values for this specific datetime
      # and test our datetime_to_julian_date function
      
      # TODO: Get reference JD_UT1 and JD_TT from Skyfield
      # For now, test that the function works
      jd = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(@test_datetime)
      assert is_float(jd)
      assert jd > 2460000.0  # Reasonable JD for 2024
    end

    test "Level 2: Fundamental arguments match Skyfield" do
      # Test the 5 Delaunay fundamental arguments
      # We need Skyfield reference values for:
      # - l (mean anomaly of Moon)
      # - l' (mean anomaly of Sun) 
      # - F (mean longitude of Moon minus longitude of ascending node)
      # - D (mean elongation of Moon from Sun)
      # - Omega (longitude of ascending node of Moon)
      
      skip("Need Skyfield reference values")
    end

    test "Level 3: Nutation series matches Skyfield" do
      # Test delta_psi and delta_epsilon calculation
      # This is where the 1431 terms are summed
      
      skip("Need Skyfield reference values")
    end

    test "Level 4: Mean obliquity matches Skyfield" do
      # Test epsilon_0 calculation
      
      skip("Need Skyfield reference values")
    end

    test "Level 5: True obliquity matches Skyfield" do
      # Test epsilon_0 + delta_epsilon
      
      skip("Need Skyfield reference values")
    end

    test "Level 6: Equation of equinoxes matches Skyfield" do
      # Test GMST + equation of equinoxes = GAST conversion
      
      skip("Need Skyfield reference values")
    end

    test "Level 7: Final GAST value matches Skyfield" do
      # Test the final GAST value that gets used in coordinate rotation
      
      skip("Need Skyfield reference values")
    end
  end
end