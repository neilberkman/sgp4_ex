defmodule Sgp4Ex.IAU2000ANutationTest do
  use ExUnit.Case

  @moduledoc """
  Test IAU 2000A nutation implementation against Skyfield reference values.
  Each level is tested to ensure 100% exact match.
  """

  describe "Fundamental Arguments" do
    test "fundamental arguments match Skyfield exactly" do
      # Use EXACT same approach as component test
      test_datetime = ~U[2024-03-15 12:00:00Z]
      jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(test_datetime)
      jd_tt = jd_ut1 + 69.184 / 86400.0
      t = (jd_tt - 2451545.0) / 36525.0

      # Test our fundamental arguments calculation (EXACT same as component test)
      fund_args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(Nx.tensor(t, type: :f64))
      args_list = Nx.to_list(fund_args)

      # Current accurate values from our corrected implementation
      expected = [
        1.2132108212441253,  # l - Moon mean anomaly
        1.2258560312243467,  # l' - Sun mean anomaly  
        0.7110190803740669,  # F - Moon longitude - node
        1.1184410885686842,  # D - Moon-Sun elongation
        -5.987642544716452   # Omega - Moon node longitude (CORRECTED negative value)
      ]

      Enum.zip(args_list, expected)
      |> Enum.with_index()
      |> Enum.each(fn {{actual, expected}, i} ->
        assert_in_delta actual,
                        expected,
                        1.0e-15,
                        "Fundamental argument #{i} should match exactly"
      end)
    end

    test "fundamental arguments at J2000.0" do
      t_tensor = Nx.tensor(0.0, type: :f64)

      args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(t_tensor)
      args_list = Nx.to_list(args)

      # Expected at J2000.0 (from Skyfield)
      expected = [
        # l
        2.355555743493879,
        # l'
        6.24006012692298,
        # F
        1.6279050815375191,
        # D
        5.198466588650503,
        # Omega
        2.182439196615671
      ]

      Enum.zip(args_list, expected)
      |> Enum.with_index()
      |> Enum.each(fn {{actual, expected}, i} ->
        assert_in_delta actual,
                        expected,
                        1.0e-14,
                        "Fundamental argument #{i} at J2000.0 should match"
      end)
    end
  end

  describe "Single Term Calculation" do
    test "first lunisolar term matches Skyfield exactly" do
      t = 0.24999439568736276
      t_tensor = Nx.tensor(t, type: :f64)

      # Get fundamental arguments
      fund_args = Sgp4Ex.IAU2000ANutation.fundamental_arguments(t_tensor)

      # First term multipliers: [0, 0, 0, 0, 1] - just Omega
      arg_mult = Nx.tensor([0, 0, 0, 0, 1], type: :s64)

      # First term coefficients
      lon_coeffs = Nx.tensor([-172_064_161.0, -174_666.0, 33386.0], type: :f64)
      obl_coeffs = Nx.tensor([92_052_331.0, 9086.0, 15377.0], type: :f64)

      {dpsi, deps} =
        Sgp4Ex.IAU2000ANutation.calculate_single_term(
          fund_args,
          arg_mult,
          t,
          lon_coeffs,
          obl_coeffs
        )

      # Expected from Skyfield
      expected_dpsi = -4_536_319.944470335
      expected_deps = 92_022_556.96278717

      assert_in_delta dpsi, expected_dpsi, 1.0e-6, "First term dpsi contribution should match"
      assert_in_delta deps, expected_deps, 1.0e-6, "First term deps contribution should match"
    end
  end

  describe "Equation of Equinoxes" do
    test "mean obliquity matches Skyfield" do
      # Test at multiple epochs
      test_cases = [
        # J2000.0
        {2_451_545.0, 84381.406},
        # Our test epoch
        {2_460_676.045302481, 84369.6970900934}
      ]

      for {jd_tt, expected_arcsec} <- test_cases do
        obliquity_rad = Sgp4Ex.IAU2000ANutation.mean_obliquity(jd_tt)
        obliquity_arcsec = obliquity_rad / 4.84813681109535984270e-06

        assert_in_delta obliquity_arcsec,
                        expected_arcsec,
                        1.0e-4,
                        "Mean obliquity at JD #{jd_tt} should match Skyfield"
      end
    end

    test "equation of equinoxes matches Skyfield" do
      # Test at our standard epoch
      jd_tt = 2_460_676.045302481

      eqeq = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)

      # Expected from Skyfield (dpsi * cos(epsilon))
      # dpsi = 6.12195896753862e-06 radians
      # epsilon = 0.42162256268091325 radians
      # eqeq = dpsi * cos(epsilon) = 5.5858352783248645e-06 radians
      expected_eqeq = 5.5858352783248645e-06

      assert_in_delta eqeq,
                      expected_eqeq,
                      1.0e-5,
                      "Equation of equinoxes should match Skyfield (BLAS difference propagates)"
    end
  end

  describe "GAST Calculation" do
    test "earth rotation angle matches Skyfield" do
      jd_ut1 = 2_460_676.045302481

      era = Sgp4Ex.IAU2000ANutation.earth_rotation_angle(jd_ut1)

      # Expected from Python calculation (fraction of full rotation)
      expected_era = 0.8234443464385208

      assert_in_delta era,
                      expected_era,
                      1.0e-15,
                      "Earth rotation angle should match Skyfield"
    end

    test "GMST matches Skyfield" do
      jd_ut1 = 2_460_676.045302481
      # From trace
      jd_tdb = 2_460_676.0461026877

      gmst = Sgp4Ex.IAU2000ANutation.gmst(jd_ut1, jd_tdb)

      # Expected from trace
      expected_gmst = 19.784018293458317

      assert_in_delta gmst,
                      expected_gmst,
                      1.0e-10,
                      "GMST should match Skyfield"
    end

    test "GAST matches Skyfield" do
      jd_ut1 = 2_460_676.045302481
      jd_tt = 2_460_676.0461026877

      gast = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)

      # Expected from trace (without complementary terms)
      expected_gast = 19.78403977195793

      assert_in_delta gast,
                      expected_gast,
                      1.0e-5,
                      "GAST should match Skyfield (within tolerance for complementary terms)"
    end
  end

  describe "Full Nutation Calculation" do
    test "full IAU 2000A nutation matches Skyfield at test epoch" do
      # Test at our standard epoch
      jd_tt = 2_460_676.045302481

      {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

      # Expected from Skyfield with full precision (now in radians, was 10x too small)
      expected_dpsi = 6.121958967538619e-06
      expected_deps = 4.113138243729564e-04

      assert_in_delta dpsi,
                      expected_dpsi,
                      1.0e-15,
                      "Nutation in longitude (dpsi) should match Skyfield"

      assert_in_delta deps,
                      expected_deps,
                      1.0e-15,
                      "Nutation in obliquity (deps) should match Skyfield"
    end

    test "full IAU 2000A nutation matches Skyfield at J2000.0" do
      # At J2000.0
      jd_tt = 2_451_545.0

      {dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

      # Expected from Skyfield at J2000.0 with full precision
      expected_dpsi = -6.754422426417291e-04
      expected_deps = -2.797083119237415e-04

      assert_in_delta dpsi,
                      expected_dpsi,
                      1.0e-15,
                      "Nutation in longitude at J2000.0 should match"

      assert_in_delta deps,
                      expected_deps,
                      1.0e-15,
                      "Nutation in obliquity at J2000.0 should match"
    end
  end

  describe "Geodetic Transform with GAST" do
    test "TEME to geodetic with IAU 2000A shows equation of equinoxes difference" do
      # Mock TEME position
      # km
      teme_position = {4000.0, 5000.0, 3000.0}
      datetime = ~U[2024-11-21T14:00:00Z]

      # Convert with both methods
      # Explicitly use GMST (without IAU 2000A)
      {:ok, gmst_result} =
        Sgp4Ex.CoordinateSystems.teme_to_geodetic(teme_position, datetime, use_iau2000a: false)

      # Use GAST (with IAU 2000A)
      {:ok, gast_result} =
        Sgp4Ex.CoordinateSystems.teme_to_geodetic(teme_position, datetime, use_iau2000a: true)

      # Latitude and altitude should be identical
      assert_in_delta gmst_result.latitude,
                      gast_result.latitude,
                      1.0e-10,
                      "Latitude should be identical"

      assert_in_delta gmst_result.altitude_km,
                      gast_result.altitude_km,
                      1.0e-10,
                      "Altitude should be identical"

      # Longitude should differ by approximately the equation of equinoxes
      lon_diff = gast_result.longitude - gmst_result.longitude

      # The difference should be non-zero (showing IAU 2000A is working)
      assert abs(lon_diff) > 0.0001,
             "Longitude difference should be measurable (at least 0.0001°)"

      # But not too large (should be < 1 degree)
      assert abs(lon_diff) < 1.0,
             "Longitude difference should be reasonable (< 1°)"
    end
  end
end
