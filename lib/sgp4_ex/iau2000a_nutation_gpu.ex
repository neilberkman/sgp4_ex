defmodule Sgp4Ex.IAU2000ANutationGPU do
  @moduledoc """
  GPU-optimized IAU 2000A nutation model implementation.
  Keeps all calculations in tensor space to avoid CPU/GPU transfers.
  """

  import Nx.Defn

  # Constants
  @j2000 2_451_545.0
  @asec2rad 4.848136811095359935899141e-6
  @asec360 1_296_000.0

  # Import coefficient data from original module
  alias Sgp4Ex.IAU2000ACoefficients

  # Pre-computed tensors to avoid Nx.tensor() calls in defnp
  @lunisolar_arg_mult_tensor Nx.tensor(IAU2000ACoefficients.lunisolar_arg_multipliers())
                             |> Nx.as_type(:s32)
  @lunisolar_lon_coeffs_tensor Nx.tensor(IAU2000ACoefficients.lunisolar_longitude_coefficients())
                               |> Nx.as_type(:f64)
  @lunisolar_obl_coeffs_tensor Nx.tensor(IAU2000ACoefficients.lunisolar_obliquity_coefficients())
                               |> Nx.as_type(:f64)
  @planetary_arg_mult_tensor Nx.tensor(IAU2000ACoefficients.planetary_arg_multipliers())
                             |> Nx.as_type(:s32)
  @planetary_lon_coeffs_tensor Nx.tensor(IAU2000ACoefficients.planetary_longitude_coefficients())
                               |> Nx.as_type(:f64)
  @planetary_obl_coeffs_tensor Nx.tensor(IAU2000ACoefficients.planetary_obliquity_coefficients())
                               |> Nx.as_type(:f64)
  @index_13_tensor Nx.tensor([[13]])

  # Fundamental arguments coefficients (same as original)
  @fa0 Nx.tensor(
         [
           3.154384999847899,
           2.357551718265301,
           1.6280158027288272,
           5.198471222772339,
           2.182438624381695,
           0.0,
           4.402675378302461,
           3.176124779336447,
           1.7534699593468917,
           6.203476112911137,
           5.4812548919868355,
           0.59953550516771,
           0.8740267519538868,
           5.371135665268745
         ],
         type: :f64
       )

  @fa1 Nx.tensor(
         [
           628_307_584_999.0,
           8_399_684.6073,
           8_433_463.1576,
           7_771_374.8964,
           -33.86238,
           0.0,
           5217.912,
           1_021_227.9348,
           628_307.5843,
           668_621.7299,
           20.082,
           529_690.8128,
           424_347.2442,
           0.5269
         ],
         type: :f64
       )

  @fa2 Nx.tensor(
         [
           0.0,
           -2.1973e-05,
           -1.1836e-05,
           -6.8416e-06,
           -1.5486e-08,
           0.0,
           0.0,
           -3.7081e-08,
           -1.1826e-07,
           0.0,
           0.0,
           -8.5463e-06,
           9.9238e-06,
           -2.228e-13
         ],
         type: :f64
       )

  @fa3 Nx.tensor(
         [
           0.0,
           5.4e-15,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0
         ],
         type: :f64
       )

  @fa4 Nx.tensor(
         [
           0.0,
           -4.5e-20,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0,
           0.0
         ],
         type: :f64
       )

  @anomaly_constant Nx.tensor(
                      [
                        2.3555559800000001,
                        6.2400601299999998,
                        1.627905234,
                        5.1984667409999998,
                        2.1824392000000001,
                        4.4026088420000002,
                        3.1761466970000001,
                        1.7534703140000001,
                        6.2034809129999999,
                        0.59954649699999996,
                        0.87401675700000003,
                        5.4812938710000001,
                        5.3211589999999998,
                        0.024381750000000001
                      ],
                      type: :f64
                    )

  @anomaly_coefficient Nx.tensor(
                         [
                           8328.6914269553999,
                           628.30195500000002,
                           8433.4661581309992,
                           7771.3771468121004,
                           -33.757044999999998,
                           2608.7903141574002,
                           1021.3285546211,
                           628.30758499909996,
                           334.06124267000001,
                           52.969096264100003,
                           21.329910496,
                           7.4781598566999996,
                           3.8127773999999999,
                           5.3869099999999999e-06
                         ],
                         type: :f64
                       )

  @doc """
  GPU-optimized IAU 2000A nutation calculation returning tensors.
  Use this when chaining GPU operations to avoid CPU transfers.
  Returns {dpsi_tensor, deps_tensor} in radians.
  """
  defn iau2000a_nutation_gpu_tensor(jd_tt) do
    # Convert to centuries since J2000
    t = (jd_tt - @j2000) / 36525.0

    # Calculate fundamental arguments
    fund_args = fundamental_arguments_gpu(t)

    # Calculate all nutation terms in one go
    {dpsi_tensor, deps_tensor} = calculate_all_nutation_gpu(fund_args, t)

    # Convert from microarcseconds to radians
    dpsi_rad = dpsi_tensor * 1.0e-6 * @asec2rad
    deps_rad = deps_tensor * 1.0e-6 * @asec2rad

    {dpsi_rad, deps_rad}
  end

  @doc """
  GPU-optimized IAU 2000A nutation calculation with scalar return.
  Converts tensor results to floats for compatibility.
  Only use this at the final step to avoid intermediate CPU transfers.
  """
  def iau2000a_nutation_gpu(jd_tt) when is_float(jd_tt) do
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    {dpsi_tensor, deps_tensor} = iau2000a_nutation_gpu_tensor(jd_tt_tensor)
    {Nx.to_number(dpsi_tensor), Nx.to_number(deps_tensor)}
  end

  defnp fundamental_arguments_gpu(t) do
    # Calculate all arguments at once using tensor operations
    args = @fa4 * t
    args = (args + @fa3) * t
    args = (args + @fa2) * t
    args = (args + @fa1) * t
    args = args + @fa0

    # Convert to radians
    Nx.remainder(args, @asec360) * @asec2rad
  end

  defnp calculate_all_nutation_gpu(fund_args, t) do
    # Use pre-computed coefficient tensors
    arg_mult = @lunisolar_arg_mult_tensor
    lon_coeffs = @lunisolar_lon_coeffs_tensor
    obl_coeffs = @lunisolar_obl_coeffs_tensor

    # Lunisolar calculations only need first 5 fundamental arguments
    fund_args_5 = fund_args[0..4]

    # Calculate all arguments at once
    # args shape: [678] (lunisolar terms)
    args = Nx.dot(arg_mult, fund_args_5)

    # Sin and cos for all arguments
    sin_args = Nx.sin(args)
    cos_args = Nx.cos(args)

    # Lunisolar contributions - fully vectorized
    dpsi_ls = calculate_dpsi_gpu(sin_args, cos_args, lon_coeffs, t)
    deps_ls = calculate_deps_gpu(sin_args, cos_args, obl_coeffs, t)

    # Planetary contributions
    {dpsi_pl, deps_pl} = calculate_planetary_gpu(t)

    # Return total nutation as tensors
    {dpsi_ls + dpsi_pl, deps_ls + deps_pl}
  end

  defnp calculate_dpsi_gpu(sin_args, cos_args, lon_coeffs, t) do
    # dpsi = sin * coeff[0] + sin * coeff[1] * t + cos * coeff[2]
    term1 = Nx.dot(sin_args, lon_coeffs[[.., 0]])
    term2 = Nx.dot(sin_args, lon_coeffs[[.., 1]]) * t
    term3 = Nx.dot(cos_args, lon_coeffs[[.., 2]])
    term1 + term2 + term3
  end

  defnp calculate_deps_gpu(sin_args, cos_args, obl_coeffs, t) do
    # deps = cos * coeff[0] + cos * coeff[1] * t + sin * coeff[2]
    term1 = Nx.dot(cos_args, obl_coeffs[[.., 0]])
    term2 = Nx.dot(cos_args, obl_coeffs[[.., 1]]) * t
    term3 = Nx.dot(sin_args, obl_coeffs[[.., 2]])
    term1 + term2 + term3
  end

  defnp calculate_planetary_gpu(t) do
    # Calculate planetary arguments
    planetary_args = @anomaly_constant + @anomaly_coefficient * t
    # Update last element - need to wrap scalar in tensor
    updated_value = Nx.reshape(planetary_args[13] * t, {1})
    planetary_args =
      Nx.indexed_put(
        planetary_args,
        @index_13_tensor,
        updated_value
      )

    # Use pre-computed planetary coefficients
    arg_mult = @planetary_arg_mult_tensor
    lon_coeffs = @planetary_lon_coeffs_tensor
    obl_coeffs = @planetary_obl_coeffs_tensor

    # Take first 687 terms
    arg_mult_687 = arg_mult[0..686]
    lon_coeffs_687 = lon_coeffs[0..686]
    obl_coeffs_687 = obl_coeffs[0..686]

    # Calculate all planetary arguments
    args = Nx.dot(arg_mult_687, planetary_args)
    sin_args = Nx.sin(args)
    cos_args = Nx.cos(args)

    # Planetary contributions: sin*c0 + cos*c1
    dpsi_pl =
      Nx.dot(sin_args, lon_coeffs_687[[.., 0]]) +
        Nx.dot(cos_args, lon_coeffs_687[[.., 1]])

    deps_pl =
      Nx.dot(sin_args, obl_coeffs_687[[.., 0]]) +
        Nx.dot(cos_args, obl_coeffs_687[[.., 1]])

    {dpsi_pl, deps_pl}
  end

  defnp mean_obliquity_gpu(jd_tt) do
    # IAU 2000 mean obliquity polynomial
    t = (jd_tt - @j2000) / 36525.0

    # Pre-computed polynomial coefficients
    c0 = Nx.tensor(-0.0000000434, type: :f64)
    c1 = Nx.tensor(-0.000000576, type: :f64)
    c2 = Nx.tensor(0.00200340, type: :f64)
    c3 = Nx.tensor(-0.0001831, type: :f64)
    c4 = Nx.tensor(-46.836769, type: :f64)
    c5 = Nx.tensor(84381.406, type: :f64)

    # Horner's method
    result = c0
    result = result * t + c1
    result = result * t + c2
    result = result * t + c3
    result = result * t + c4
    result = result * t + c5

    # Convert to radians
    result * @asec2rad
  end

  defnp earth_rotation_angle_gpu(jd_ut1, fraction_ut1) do
    # From IAU Resolution B1.8 of 2000
    theta_base = Nx.tensor(0.7790572732640, type: :f64)
    theta_rate = Nx.tensor(0.00273781191135448, type: :f64)

    theta = theta_base + theta_rate * (jd_ut1 - @j2000 + fraction_ut1)

    # Normalize to [0, 1)
    # Note: Nx doesn't have fmod, so we use remainder
    theta_normalized = Nx.remainder(theta, 1.0)
    jd_frac = Nx.remainder(jd_ut1, 1.0)

    total = theta_normalized + jd_frac + fraction_ut1
    Nx.remainder(total, 1.0)
  end

  defnp gmst_gpu_tensor(jd_ut1, jd_tdb, fraction_ut1, fraction_tdb) do
    # Earth rotation angle
    theta = earth_rotation_angle_gpu(jd_ut1, fraction_ut1)

    # Precession-in-RA terms
    t = (jd_tdb - @j2000 + fraction_tdb) / 36525.0

    # Polynomial coefficients
    c0 = Nx.tensor(0.014506, type: :f64)
    c1 = Nx.tensor(4612.156534, type: :f64)
    c2 = Nx.tensor(1.3915817, type: :f64)
    c3 = Nx.tensor(-0.00000044, type: :f64)
    c4 = Nx.tensor(-0.000029956, type: :f64)
    c5 = Nx.tensor(-0.0000000368, type: :f64)

    # Horner's method
    st = c0
    st = st + c1 * t
    st = st + c2 * t * t
    st = st + c3 * t * t * t
    st = st + c4 * t * t * t * t
    st = st + c5 * t * t * t * t * t

    # Convert to hours and combine with Earth rotation
    gmst_hours = st / 54000.0 + theta * 24.0
    Nx.remainder(gmst_hours, 24.0)
  end

  @doc """
  GPU-optimized GAST calculation returning tensor.
  Keeps all calculations in GPU land.
  """
  defn gast_gpu_tensor(jd_ut1, jd_tt, fraction_ut1, fraction_tt) do
    # Assume TDB = TT
    jd_tdb = jd_tt
    fraction_tdb = fraction_tt

    # Get GMST in tensor form
    gmst_hours = gmst_gpu_tensor(jd_ut1, jd_tdb, fraction_ut1, fraction_tdb)

    # Get nutation and mean obliquity in tensor form
    {dpsi_tensor, _deps_tensor} = iau2000a_nutation_gpu_tensor(jd_tt)
    epsilon_tensor = mean_obliquity_gpu(jd_tt)

    # Equation of equinoxes: dpsi * cos(epsilon)
    eqeq_rad = dpsi_tensor * Nx.cos(epsilon_tensor)

    # Convert to hours
    eqeq_hours = eqeq_rad * 12.0 / Nx.Constants.pi()

    # GAST = GMST + equation of equinoxes
    gast_hours = gmst_hours + eqeq_hours
    Nx.remainder(gast_hours, 24.0)
  end

  defn gast_to_radians_gpu(gast_hours_tensor) do
    # Convert hours to radians: hours * 15° * π/180°
    # Pre-compute: 15 * π/180 = π/12
    hours_to_rad = Nx.Constants.pi() / 12.0

    gast_rad = gast_hours_tensor * hours_to_rad
    Nx.remainder(gast_rad, 2.0 * Nx.Constants.pi())
  end

  @doc """
  GPU-optimized GAST calculation with scalar inputs and output.
  Wrapper for compatibility with existing code.
  """
  def gast_gpu(jd_ut1, jd_tt, fraction_ut1 \\ 0.0, fraction_tt \\ 0.0) do
    jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    fraction_ut1_tensor = Nx.tensor(fraction_ut1, type: :f64)
    fraction_tt_tensor = Nx.tensor(fraction_tt, type: :f64)

    gast_tensor =
      gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, fraction_ut1_tensor, fraction_tt_tensor)

    Nx.to_number(gast_tensor)
  end

  @doc """
  GPU-optimized rotation from TEME to ECEF coordinates.
  Applies Z-axis rotation based on sidereal time.

  ## Parameters
  - `teme_positions` - Tensor of shape {n, 3} or {3} with TEME positions
  - `sidereal_time_rad` - Sidereal time in radians as a tensor

  ## Returns
  Tensor of same shape with ECEF positions
  """
  defn rotate_teme_to_ecef_gpu(teme_positions, sidereal_time_rad) do
    # Extract components
    x = teme_positions[[.., 0]]
    y = teme_positions[[.., 1]]
    z = teme_positions[[.., 2]]

    # Calculate sin and cos once
    cos_st = Nx.cos(sidereal_time_rad)
    sin_st = Nx.sin(sidereal_time_rad)

    # Apply rotation about Z-axis
    x_ecef = cos_st * x + sin_st * y
    y_ecef = -sin_st * x + cos_st * y
    z_ecef = z

    # Stack back into position tensor
    Nx.stack([x_ecef, y_ecef, z_ecef], axis: -1)
  end
end
