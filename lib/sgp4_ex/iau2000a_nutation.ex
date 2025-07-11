defmodule Sgp4Ex.IAU2000ANutation do
  @moduledoc """
  IAU 2000A nutation model implementation using Nx tensors.
  
  Automatically uses CPU or GPU backend based on what Nx detects.
  Uses tensor operations for maximum performance on available hardware.
  """

  import Nx.Defn

  # Constants
  @j2000 2_451_545.0
  @asec2rad 4.848136811095359935899141e-6
  @asec360 1_296_000.0

  # Import coefficient data
  alias Sgp4Ex.IAU2000ACoefficients

  # Pre-computed tensors for tensor operations
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

  # Fundamental arguments coefficients (from Skyfield)
  # fa0: constant terms in arcseconds
  @fa0 Nx.tensor(
         [
           485868.249036,
           1287104.79305,
           335779.526232,
           1072260.70369,
           450160.398036,
           4.402608842 * 206264.8062470964,
           3.176146697 * 206264.8062470964,
           1.753470314 * 206264.8062470964,
           6.203480913 * 206264.8062470964,
           0.599546497 * 206264.8062470964,
           0.874016757 * 206264.8062470964,
           5.481293872 * 206264.8062470964,
           5.311886287 * 206264.8062470964,
           0.024381750 * 206264.8062470964
         ],
         type: :f64
       )

  # fa1: linear terms in arcseconds/century
  @fa1 Nx.tensor(
         [
           1717915923.2178,
           129596581.0481,
           1739527262.8478,
           1602961601.2090,
           -6962890.5431,
           2608.7903141574 * 206264.8062470964,
           1021.3285546211 * 206264.8062470964,
           628.3075849991 * 206264.8062470964,
           334.0612426700 * 206264.8062470964,
           52.9690962641 * 206264.8062470964,
           21.3299104960 * 206264.8062470964,
           7.4781598567 * 206264.8062470964,
           3.8133035638 * 206264.8062470964,
           0.00000538691 * 206264.8062470964
         ],
         type: :f64
       )

  # fa2: quadratic terms in arcseconds/century^2  
  @fa2 Nx.tensor(
         [
           31.8792,
           -0.5532,
           -12.7512,
           -6.3706,
           7.4722,
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

  # fa3: cubic terms in arcseconds/century^3
  @fa3 Nx.tensor(
         [
           0.051635,
           0.000136,
           -0.001037,
           0.006593,
           0.007702,
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

  # fa4: quartic terms in arcseconds/century^4
  @fa4 Nx.tensor(
         [
           -0.00024470,
           -0.00001149,
           0.00000417,
           -0.00003169,
           -0.00005939,
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
  Calculate IAU 2000A nutation in longitude and obliquity.
  Returns {dpsi, deps} in radians.
  Automatically uses CPU or GPU backend based on Nx configuration.
  """
  def iau2000a_nutation(jd_tt) when is_float(jd_tt) do
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    {dpsi_tensor, deps_tensor} = iau2000a_nutation_tensor(jd_tt_tensor)
    {Nx.to_number(dpsi_tensor), Nx.to_number(deps_tensor)}
  end

  @doc """
  Tensor version for chaining operations.
  """
  defn iau2000a_nutation_tensor(jd_tt) do
    # Convert to centuries since J2000
    t = (jd_tt - @j2000) / 36525.0

    # Calculate fundamental arguments
    fund_args = fundamental_arguments(t)

    # Calculate all nutation terms
    {dpsi_tensor, deps_tensor} = calculate_all_nutation(fund_args, t)

    # Convert from 0.1 microarcseconds to radians
    dpsi_rad = dpsi_tensor * 1.0e-7 * @asec2rad
    deps_rad = deps_tensor * 1.0e-7 * @asec2rad

    {dpsi_rad, deps_rad}
  end

  defnp fundamental_arguments(t) do
    # Calculate all arguments at once using tensor operations
    args = @fa4 * t
    args = (args + @fa3) * t
    args = (args + @fa2) * t
    args = (args + @fa1) * t
    args = args + @fa0

    # Convert to radians
    Nx.remainder(args, @asec360) * @asec2rad
  end

  defnp calculate_all_nutation(fund_args, t) do
    # Use pre-computed coefficient tensors
    arg_mult = @lunisolar_arg_mult_tensor
    lon_coeffs = @lunisolar_lon_coeffs_tensor
    obl_coeffs = @lunisolar_obl_coeffs_tensor

    # Lunisolar calculations only need first 5 fundamental arguments
    fund_args_5 = fund_args[0..4]

    # Calculate all arguments at once
    args = Nx.dot(arg_mult, fund_args_5)

    # Sin and cos for all arguments
    sin_args = Nx.sin(args)
    cos_args = Nx.cos(args)

    # Lunisolar contributions - fully vectorized
    dpsi_ls = calculate_dpsi(sin_args, cos_args, lon_coeffs, t)
    deps_ls = calculate_deps(sin_args, cos_args, obl_coeffs, t)

    # Planetary contributions
    {dpsi_pl, deps_pl} = calculate_planetary(t)

    # Return total nutation as tensors
    {dpsi_ls + dpsi_pl, deps_ls + deps_pl}
  end

  defnp calculate_dpsi(sin_args, cos_args, lon_coeffs, t) do
    # dpsi = sin * coeff[0] + sin * coeff[1] * t + cos * coeff[2]
    term1 = Nx.dot(sin_args, lon_coeffs[[.., 0]])
    term2 = Nx.dot(sin_args, lon_coeffs[[.., 1]]) * t
    term3 = Nx.dot(cos_args, lon_coeffs[[.., 2]])
    term1 + term2 + term3
  end

  defnp calculate_deps(sin_args, cos_args, obl_coeffs, t) do
    # deps = cos * coeff[0] + cos * coeff[1] * t + sin * coeff[2]
    term1 = Nx.dot(cos_args, obl_coeffs[[.., 0]])
    term2 = Nx.dot(cos_args, obl_coeffs[[.., 1]]) * t
    term3 = Nx.dot(sin_args, obl_coeffs[[.., 2]])
    term1 + term2 + term3
  end

  defnp calculate_planetary(t) do
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

  defnp mean_obliquity_tensor(jd_tt) do
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

  @doc """
  Calculate the mean obliquity of the ecliptic.
  """
  def mean_obliquity(jd_tt) when is_float(jd_tt) do
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    mean_obliquity_tensor(jd_tt_tensor) |> Nx.to_number()
  end

  defnp earth_rotation_angle_tensor(jd_ut1, fraction_ut1) do
    # From IAU Resolution B1.8 of 2000
    theta_base = Nx.tensor(0.7790572732640, type: :f64)
    theta_rate = Nx.tensor(0.00273781191135448, type: :f64)

    theta = theta_base + theta_rate * (jd_ut1 - @j2000 + fraction_ut1)

    # Normalize to [0, 1)
    theta_normalized = Nx.remainder(theta, 1.0)
    jd_frac = Nx.remainder(jd_ut1, 1.0)

    total = theta_normalized + jd_frac + fraction_ut1
    Nx.remainder(total, 1.0)
  end

  defnp gmst_tensor(jd_ut1, jd_tdb, fraction_ut1, fraction_tdb) do
    # Earth rotation angle
    theta = earth_rotation_angle_tensor(jd_ut1, fraction_ut1)

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
  Calculate Greenwich Apparent Sidereal Time (GAST).
  Automatically uses CPU or GPU backend based on Nx configuration.
  """
  def gast(jd_ut1, jd_tt, fraction_ut1 \\ 0.0, fraction_tt \\ 0.0) do
    jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    fraction_ut1_tensor = Nx.tensor(fraction_ut1, type: :f64)
    fraction_tt_tensor = Nx.tensor(fraction_tt, type: :f64)

    gast_tensor = gast_tensor(jd_ut1_tensor, jd_tt_tensor, fraction_ut1_tensor, fraction_tt_tensor)
    Nx.to_number(gast_tensor)
  end

  @doc """
  Tensor version of GAST calculation for chaining operations.
  """
  defn gast_tensor(jd_ut1, jd_tt, fraction_ut1, fraction_tt) do
    # Assume TDB = TT
    jd_tdb = jd_tt
    fraction_tdb = fraction_tt

    # Get GMST in tensor form
    gmst_hours = gmst_tensor(jd_ut1, jd_tdb, fraction_ut1, fraction_tdb)

    # Get nutation and mean obliquity in tensor form
    {dpsi_tensor, _deps_tensor} = iau2000a_nutation_tensor(jd_tt)
    epsilon_tensor = mean_obliquity_tensor(jd_tt)

    # Equation of equinoxes: dpsi * cos(epsilon)
    eqeq_rad = dpsi_tensor * Nx.cos(epsilon_tensor)

    # Convert to hours
    eqeq_hours = eqeq_rad * 12.0 / Nx.Constants.pi()

    # GAST = GMST + equation of equinoxes
    gast_hours = gmst_hours + eqeq_hours
    Nx.remainder(gast_hours, 24.0)
  end

  @doc """
  Calculate equation of equinoxes from pre-computed components.
  """
  def equation_of_equinoxes_from_components(dpsi, epsilon) do
    dpsi * :math.cos(epsilon)
  end
end