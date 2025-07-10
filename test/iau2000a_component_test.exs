defmodule Sgp4Ex.IAU2000AComponentTest do
  use ExUnit.Case

  @moduledoc """
  Component-level tests for IAU 2000A implementation.
  Tests each calculation level against Skyfield reference values.
  """

  # Test datetime - same as our failing case
  @test_datetime ~U[2024-03-15 12:00:00Z]

  # Skyfield reference values for 2024-03-15 12:00:00 UTC
  @skyfield_jd_ut1 2460384.999999894
  @skyfield_jd_tt 2460385.000800741
  @skyfield_gast_hours 23.572220420489195
  @skyfield_gmst_hours 23.572220416610136
  @skyfield_eq_eq_hours 3.879058773358244e-09

  # Fundamental arguments (radians)
  @skyfield_l -4.023100281130396      # Moon mean anomaly
  @skyfield_l_prime -1.1064611755754274 # Sun mean anomaly  
  @skyfield_f 3.020893439540763        # Moon longitude - node
  @skyfield_d -3.4012976462865496      # Moon-Sun elongation
  @skyfield_omega -2.240227057670944   # Moon node longitude

  describe "IAU 2000A component breakdown" do
    test "Level 1: Julian date conversion matches Skyfield" do
      jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(@test_datetime)
      # For simplicity, assume UT1 = UTC and TT = UTC + 69.184s
      jd_tt = jd_ut1 + 69.184 / 86400.0

      assert_in_delta jd_ut1, @skyfield_jd_ut1, 0.000001, "JD_UT1 mismatch"
      assert_in_delta jd_tt, @skyfield_jd_tt, 0.000001, "JD_TT mismatch"
    end

    test "Level 2: Fundamental arguments match Skyfield" do
      # Get our Julian TT
      jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(@test_datetime)
      jd_tt = jd_ut1 + 69.184 / 86400.0

      # Calculate centuries since J2000 for IAU 2000A
      t = (jd_tt - 2451545.0) / 36525.0

      # Test our fundamental arguments calculation
      fund_args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(Nx.tensor(t, type: :f64))
      args_list = Nx.to_list(fund_args)

      # Compare with Skyfield reference values (radians)
      assert_in_delta Enum.at(args_list, 0), @skyfield_l, 0.000001, "l (Moon mean anomaly) mismatch"
      assert_in_delta Enum.at(args_list, 1), @skyfield_l_prime, 0.000001, "l' (Sun mean anomaly) mismatch"
      assert_in_delta Enum.at(args_list, 2), @skyfield_f, 0.000001, "F (Moon longitude - node) mismatch"
      assert_in_delta Enum.at(args_list, 3), @skyfield_d, 0.000001, "D (Moon-Sun elongation) mismatch"
      assert_in_delta Enum.at(args_list, 4), @skyfield_omega, 0.000001, "Omega (Moon node longitude) mismatch"
    end

    @tag :skip
    test "Level 3: Nutation series matches Skyfield" do
      # Test delta_psi and delta_epsilon calculation
      # This is where the 1431 terms are summed
      
      assert false, "Need Skyfield reference values"
    end

    @tag :skip
    test "Level 4: Mean obliquity matches Skyfield" do
      # Test epsilon_0 calculation
      
      assert false, "Need Skyfield reference values"
    end

    @tag :skip
    test "Level 5: True obliquity matches Skyfield" do
      # Test epsilon_0 + delta_epsilon
      
      assert false, "Need Skyfield reference values"
    end

    @tag :skip
    test "Level 6: Equation of equinoxes matches Skyfield" do
      # Test GMST + equation of equinoxes = GAST conversion
      
      assert false, "Need Skyfield reference values"
    end

    @tag :skip
    test "Level 7: Final GAST value matches Skyfield" do
      # Test the final GAST value that gets used in coordinate rotation
      
      assert false, "Need Skyfield reference values"
    end
  end
end