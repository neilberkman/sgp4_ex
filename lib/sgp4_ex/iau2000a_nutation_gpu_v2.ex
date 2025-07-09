defmodule Sgp4Ex.IAU2000ANutationGPUV2 do
  @moduledoc """
  GPU-optimized IAU 2000A nutation model implementation V2.
  Pre-loads all coefficients as tensors to avoid defn warnings.
  """
  
  import Nx.Defn
  
  # Constants
  @j2000 2451545.0
  @asec2rad 4.848136811095359935899141e-6
  @asec360 1296000.0
  
  # Import coefficient data
  alias Sgp4Ex.IAU2000ACoefficients
  
  # Pre-load all coefficients as module attributes
  @lunisolar_arg_mult IAU2000ACoefficients.lunisolar_arg_multipliers()
  @lunisolar_lon_coeffs IAU2000ACoefficients.lunisolar_longitude_coefficients()
  @lunisolar_obl_coeffs IAU2000ACoefficients.lunisolar_obliquity_coefficients()
  
  @planetary_arg_mult IAU2000ACoefficients.planetary_arg_multipliers()
  @planetary_lon_coeffs IAU2000ACoefficients.planetary_longitude_coefficients()
  @planetary_obl_coeffs IAU2000ACoefficients.planetary_obliquity_coefficients()
  
  # Convert to tensors at compile time
  @lunisolar_arg_mult_tensor Nx.tensor(@lunisolar_arg_mult, type: :s64)
  @lunisolar_lon_coeffs_tensor Nx.tensor(@lunisolar_lon_coeffs, type: :f64)
  @lunisolar_obl_coeffs_tensor Nx.tensor(@lunisolar_obl_coeffs, type: :f64)
  
  @planetary_arg_mult_tensor Nx.tensor(@planetary_arg_mult, type: :s64)
  @planetary_lon_coeffs_tensor Nx.tensor(@planetary_lon_coeffs, type: :f64)
  @planetary_obl_coeffs_tensor Nx.tensor(@planetary_obl_coeffs, type: :f64)
  
  # Take first 687 planetary terms
  @planetary_arg_mult_687 Nx.slice(@planetary_arg_mult_tensor, [0, 0], [687, 14])
  @planetary_lon_coeffs_687 Nx.slice(@planetary_lon_coeffs_tensor, [0, 0], [687, 2])
  @planetary_obl_coeffs_687 Nx.slice(@planetary_obl_coeffs_tensor, [0, 0], [687, 2])
  
  # Fundamental arguments coefficients
  @fa0 Nx.tensor([
    3.154384999847899, 2.357551718265301, 1.6280158027288272,
    5.198471222772339, 2.182438624381695, 0.0,
    4.402675378302461, 3.176124779336447, 1.7534699593468917,
    6.203476112911137, 5.4812548919868355, 0.59953550516771,
    0.8740267519538868, 5.371135665268745
  ], type: :f64)
  
  @fa1 Nx.tensor([
    628307584999.0, 8399684.6073, 8433463.1576,
    7771374.8964, -33.86238, 0.0,
    5217.912, 1021227.9348, 628307.5843,
    668621.7299, 20.082, 529690.8128,
    424347.2442, 0.5269
  ], type: :f64)
  
  @fa2 Nx.tensor([
    0.0, -2.1973e-05, -1.1836e-05,
    -6.8416e-06, -1.5486e-08, 0.0,
    0.0, -3.7081e-08, -1.1826e-07,
    0.0, 0.0, -8.5463e-06,
    9.9238e-06, -2.228e-13
  ], type: :f64)
  
  @fa3 Nx.tensor([
    0.0, 5.4e-15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
  ], type: :f64)
  
  @fa4 Nx.tensor([
    0.0, -4.5e-20, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
  ], type: :f64)
  
  @anomaly_constant Nx.tensor([
    2.3555559800000001, 6.2400601299999998, 1.627905234,
    5.1984667409999998, 2.1824392000000001, 4.4026088420000002,
    3.1761466970000001, 1.7534703140000001, 6.2034809129999999,
    0.59954649699999996, 0.87401675700000003, 5.4812938710000001,
    5.3211589999999998, 0.024381750000000001
  ], type: :f64)
  
  @anomaly_coefficient Nx.tensor([
    8328.6914269553999, 628.30195500000002, 8433.4661581309992,
    7771.3771468121004, -33.757044999999998, 2608.7903141574002,
    1021.3285546211, 628.30758499909996, 334.06124267000001,
    52.969096264100003, 21.329910496, 7.4781598566999996,
    3.8127773999999999, 5.3869099999999999e-06
  ], type: :f64)

  @doc """
  GPU-optimized IAU 2000A nutation calculation.
  Returns nutation in longitude and obliquity in radians.
  """
  def iau2000a_nutation_gpu(jd_tt) when is_float(jd_tt) do
    jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
    {dpsi_tensor, deps_tensor} = iau2000a_nutation_gpu_tensor(jd_tt_tensor)
    {Nx.to_number(dpsi_tensor), Nx.to_number(deps_tensor)}
  end
  
  defn iau2000a_nutation_gpu_tensor(jd_tt) do
    # Convert to centuries since J2000
    t = (jd_tt - @j2000) / 36525.0
    
    # Calculate fundamental arguments
    fund_args = fundamental_arguments_gpu(t)
    
    # Calculate all nutation terms
    {dpsi_tensor, deps_tensor} = calculate_all_nutation_gpu(fund_args, t)
    
    # Convert from microarcseconds to radians
    dpsi_rad = dpsi_tensor * 1.0e-6 * @asec2rad
    deps_rad = deps_tensor * 1.0e-6 * @asec2rad
    
    {dpsi_rad, deps_rad}
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
    # Take only first 5 fundamental arguments for lunisolar calculations
    fund_args_5 = Nx.slice(fund_args, [0], [5])
    
    # Calculate all lunisolar arguments at once
    # args shape: [1365]
    args = Nx.dot(@lunisolar_arg_mult_tensor, fund_args_5)
    
    # Sin and cos for all arguments
    sin_args = Nx.sin(args)
    cos_args = Nx.cos(args)
    
    # Lunisolar contributions - fully vectorized
    dpsi_ls = calculate_dpsi_gpu(sin_args, cos_args, @lunisolar_lon_coeffs_tensor, t)
    deps_ls = calculate_deps_gpu(sin_args, cos_args, @lunisolar_obl_coeffs_tensor, t)
    
    # Planetary contributions
    {dpsi_pl, deps_pl} = calculate_planetary_gpu(t)
    
    # Return total nutation
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
    # Update last element by multiplying by t
    last_value = planetary_args[13] * t
    planetary_args = Nx.indexed_put(
      planetary_args,
      Nx.tensor([13]),
      last_value
    )
    
    # Calculate all planetary arguments
    args = Nx.dot(@planetary_arg_mult_687, planetary_args)
    sin_args = Nx.sin(args)
    cos_args = Nx.cos(args)
    
    # Planetary contributions: sin*c0 + cos*c1
    dpsi_pl = Nx.dot(sin_args, @planetary_lon_coeffs_687[[.., 0]]) + 
              Nx.dot(cos_args, @planetary_lon_coeffs_687[[.., 1]])
    
    deps_pl = Nx.dot(sin_args, @planetary_obl_coeffs_687[[.., 0]]) + 
              Nx.dot(cos_args, @planetary_obl_coeffs_687[[.., 1]])
    
    {dpsi_pl, deps_pl}
  end
end