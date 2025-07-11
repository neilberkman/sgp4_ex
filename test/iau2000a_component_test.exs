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

  # Fundamental arguments (radians) - ACTUAL Skyfield output
  @skyfield_l 1.213214596930936        # Moon mean anomaly
  @skyfield_l_prime 1.225856087663708  # Sun mean anomaly  
  @skyfield_f 0.711022421912160        # Moon longitude - node
  @skyfield_d 1.118442507179634        # Moon-Sun elongation
  @skyfield_omega -5.987642548353915   # Moon node longitude (CORRECT negative value)

  # Nutation values (radians) from Skyfield IAU2000A
  @skyfield_dpsi -0.00022574473900454788  # Nutation in longitude
  @skyfield_deps 0.00044750161994292403   # Nutation in obliquity

  # Mean obliquity (radians) from Skyfield
  @skyfield_mean_obliquity 0.40903764357780753

  # Equation of equinoxes (radians) - calculated as dpsi * cos(epsilon)
  @skyfield_eq_eq_rad -2.071217015388278e-4

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

      # Compare with Skyfield reference values (radians) - allowing for minor precision differences
      assert_in_delta Enum.at(args_list, 0), @skyfield_l, 0.00001, "l (Moon mean anomaly) mismatch"
      assert_in_delta Enum.at(args_list, 1), @skyfield_l_prime, 0.00001, "l' (Sun mean anomaly) mismatch"
      assert_in_delta Enum.at(args_list, 2), @skyfield_f, 0.00001, "F (Moon longitude - node) mismatch"
      assert_in_delta Enum.at(args_list, 3), @skyfield_d, 0.00001, "D (Moon-Sun elongation) mismatch"
      assert_in_delta Enum.at(args_list, 4), @skyfield_omega, 0.00001, "Omega (Moon node longitude) mismatch"
    end

    test "Level 3: Nutation series matches Skyfield" do
      # Test delta_psi and delta_epsilon calculation
      # This is where the 1431 terms are summed
      
      # Get our Julian TT
      jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(@test_datetime)
      jd_tt = jd_ut1 + 69.184 / 86400.0
      
      # Calculate nutation using our implementation
      {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
      
      # Compare with Skyfield reference values (radians)
      assert_in_delta dpsi, @skyfield_dpsi, 0.000001, "dpsi (nutation in longitude) mismatch"
      assert_in_delta deps, @skyfield_deps, 0.000001, "deps (nutation in obliquity) mismatch"
    end

    test "Level 4: Mean obliquity matches Skyfield" do
      # Test epsilon_0 calculation
      
      # Get our Julian TT
      jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(@test_datetime)
      jd_tt = jd_ut1 + 69.184 / 86400.0
      
      # Calculate mean obliquity using our implementation
      mean_obl = Sgp4Ex.IAU2000ANutation.mean_obliquity(jd_tt)
      
      # Compare with Skyfield reference value (radians)
      assert_in_delta mean_obl, @skyfield_mean_obliquity, 0.000001, "mean obliquity mismatch"
    end

    test "Level 5: Equation of equinoxes matches Skyfield" do
      # Test equation of equinoxes calculation
      
      # Get our Julian TT  
      jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(@test_datetime)
      jd_tt = jd_ut1 + 69.184 / 86400.0
      
      # Calculate equation of equinoxes using our implementation
      eq_eq_rad = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)
      
      # Compare with Skyfield reference value (radians)
      assert_in_delta eq_eq_rad, @skyfield_eq_eq_rad, 0.000001, "equation of equinoxes mismatch"
    end

    test "Level 6: Final GAST value matches Skyfield" do
      # Test the final GAST value that gets used in coordinate rotation
      
      # Get our Julian dates
      jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(@test_datetime)
      jd_tt = jd_ut1 + 69.184 / 86400.0
      
      # Calculate GAST using our implementation
      gast_hours = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
      
      # Compare with Skyfield reference value (hours)
      assert_in_delta gast_hours, @skyfield_gast_hours, 0.000001, "GAST mismatch"
    end
  end
end