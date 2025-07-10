# Debug fundamental arguments calculation step by step

datetime = ~U[2024-03-15 12:00:00Z]
jd_ut1 = Sgp4Ex.CoordinateSystems.datetime_to_julian_date(datetime)
jd_tt = jd_ut1 + 69.184 / 86400.0
t = (jd_tt - 2451545.0) / 36525.0

IO.puts("=== STEP BY STEP COMPARISON ===")
IO.puts("t value: #{t}")

# Get our coefficients
fa0 = Sgp4Ex.IAU2000ACoefficients.fa0() |> Nx.squeeze() |> Nx.to_list()
fa1 = Sgp4Ex.IAU2000ACoefficients.fa1() |> Nx.squeeze() |> Nx.to_list()
fa2 = Sgp4Ex.IAU2000ACoefficients.fa2() |> Nx.squeeze() |> Nx.to_list()
fa3 = Sgp4Ex.IAU2000ACoefficients.fa3() |> Nx.squeeze() |> Nx.to_list()
fa4 = Sgp4Ex.IAU2000ACoefficients.fa4() |> Nx.squeeze() |> Nx.to_list()

IO.puts("First few coefficients:")
IO.puts("fa0[0]: #{Enum.at(fa0, 0)}")
IO.puts("fa1[0]: #{Enum.at(fa1, 0)}")
IO.puts("fa4[0]: #{Enum.at(fa4, 0)}")

# Calculate just the first element (l) manually using Skyfield method
fa4_0 = Enum.at(fa4, 0)
fa3_0 = Enum.at(fa3, 0)
fa2_0 = Enum.at(fa2, 0)
fa1_0 = Enum.at(fa1, 0)
fa0_0 = Enum.at(fa0, 0)

# Skyfield polynomial evaluation
a = fa4_0 * t
IO.puts("After fa4*t: #{a}")
a = (a + fa3_0) * t
IO.puts("After +fa3, *t: #{a}")
a = (a + fa2_0) * t  
IO.puts("After +fa2, *t: #{a}")
a = (a + fa1_0) * t
IO.puts("After +fa1, *t: #{a}")
a = a + fa0_0
IO.puts("After +fa0: #{a}")

# Apply angle wrapping - test different methods
asec360 = 1_296_000.0
a_wrapped_positive = a - asec360 * Float.floor(a / asec360)
IO.puts("Wrapped (always positive): #{a_wrapped_positive}")

# Try Python fmod equivalent (can be negative)
# fmod(a, asec360) in Python is equivalent to: a - asec360 * trunc(a / asec360)
a_wrapped_fmod = a - asec360 * Float.floor(a / asec360)
if a_wrapped_fmod > asec360 / 2 do
  a_wrapped_fmod = a_wrapped_fmod - asec360
end
IO.puts("Wrapped (can be negative): #{a_wrapped_fmod}")

# Also try direct remainder
a_remainder = :math.fmod(a, asec360)
IO.puts("Using erlang fmod: #{a_remainder}")

# Try wrapping to [-ASEC360/2, ASEC360/2] range
half_circle = asec360 / 2
a_wrapped_centered = a_remainder
if a_wrapped_centered > half_circle do
  a_wrapped_centered = a_wrapped_centered - asec360
end
IO.puts("Wrapped to centered range: #{a_wrapped_centered}")

# Convert to radians and try different offsets
asec2rad = 4.84813681109535984270e-06
a_rad = a_wrapped_centered * asec2rad
IO.puts("Final result in radians: #{a_rad}")

# Try subtracting 2π to get closer to expected value
expected = -4.023100281130396
a_rad_minus_2pi = a_rad - 2 * :math.pi()
a_rad_minus_4pi = a_rad - 4 * :math.pi()

IO.puts("")
IO.puts("Expected from Skyfield: #{expected}")
IO.puts("Our result: #{a_rad}")
IO.puts("Our result - 2π: #{a_rad_minus_2pi}")
IO.puts("Our result - 4π: #{a_rad_minus_4pi}")

IO.puts("Difference from expected: #{a_rad - expected}")
IO.puts("Difference (- 2π): #{a_rad_minus_2pi - expected}")
IO.puts("Difference (- 4π): #{a_rad_minus_4pi - expected}")

# The issue might be our angle range. Let me try wrapping to full 2π range
a_arcsec_to_rad_direct = a * asec2rad
a_wrapped_2pi = a_arcsec_to_rad_direct - 2 * :math.pi() * Float.floor(a_arcsec_to_rad_direct / (2 * :math.pi()))
if a_wrapped_2pi > :math.pi() do
  a_wrapped_2pi = a_wrapped_2pi - 2 * :math.pi()
end
IO.puts("Wrapped to [-π, π]: #{a_wrapped_2pi}")
IO.puts("Difference from expected: #{a_wrapped_2pi - expected}")

# Test our Nx implementation
IO.puts("")
IO.puts("=== OUR NX IMPLEMENTATION ===")
our_result = Sgp4Ex.IAU2000ANutation.fundamental_arguments(Nx.tensor(t, type: :f64))
our_l = Nx.to_number(our_result[0])
IO.puts("Our result for l: #{our_l}")
IO.puts("Difference from manual: #{our_l - a_rad}")