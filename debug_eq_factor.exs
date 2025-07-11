#!/usr/bin/env elixir

# Debug script to test equation of equinoxes calculation
# Tests with and without factor of 10 division using our calculated nutation values

Mix.install([
  {:sgp4_ex, path: "."}
])

defmodule DebugEquationOfEquinoxes do
  alias Sgp4Ex.IAU2000ANutation

  def run do
    # Test date: 2024-03-15 12:00:00Z
    test_date = ~U[2024-03-15 12:00:00Z]
    
    IO.puts("=== Equation of Equinoxes Debug Test ===")
    IO.puts("Test date: #{test_date}")
    IO.puts("")
    
    # Calculate Julian date
    jd = datetime_to_julian_date(test_date)
    IO.puts("Julian Date: #{jd}")
    
    # Calculate TT centuries since J2000.0
    tt_centuries = (jd - 2451545.0) / 36525.0
    IO.puts("TT centuries since J2000.0: #{tt_centuries}")
    IO.puts("")
    
    # Calculate nutation values using our implementation
    {dpsi, deps} = IAU2000ANutation.iau2000a_nutation(jd)
    
    IO.puts("=== Our Calculated Nutation Values ===")
    IO.puts("dpsi (nutation in longitude): #{dpsi} radians")
    IO.puts("deps (nutation in obliquity): #{deps} radians")
    IO.puts("")
    
    # Calculate mean obliquity of ecliptic
    epsilon_0 = calculate_mean_obliquity(tt_centuries)
    IO.puts("Mean obliquity (ε₀): #{epsilon_0} radians")
    
    # Calculate true obliquity
    epsilon = epsilon_0 + deps
    IO.puts("True obliquity (ε): #{epsilon} radians")
    IO.puts("")
    
    # Calculate equation of equinoxes WITHOUT factor of 10 division
    eq_eq_without_factor = dpsi * :math.cos(epsilon)
    IO.puts("=== Equation of Equinoxes Calculations ===")
    IO.puts("Without /10 factor: #{eq_eq_without_factor}")
    
    # Calculate equation of equinoxes WITH factor of 10 division
    eq_eq_with_factor = (dpsi * :math.cos(epsilon)) / 10.0
    IO.puts("With /10 factor: #{eq_eq_with_factor}")
    IO.puts("")
    
    # Reference Skyfield values from component test
    skyfield_eq_eq_main = -2.071217015388278e-5
    skyfield_eq_eq_complementary = 3.879058773358243e-09
    skyfield_eq_eq_total = skyfield_eq_eq_main + skyfield_eq_eq_complementary
    
    IO.puts("=== Skyfield Reference Values ===")
    IO.puts("Skyfield main term: #{skyfield_eq_eq_main}")
    IO.puts("Skyfield complementary term: #{skyfield_eq_eq_complementary}")
    IO.puts("Skyfield total: #{skyfield_eq_eq_total}")
    IO.puts("")
    
    # Compare differences
    diff_without_factor = abs(eq_eq_without_factor - skyfield_eq_eq_total)
    diff_with_factor = abs(eq_eq_with_factor - skyfield_eq_eq_total)
    
    IO.puts("=== Comparison with Skyfield ===")
    IO.puts("Difference without /10 factor: #{diff_without_factor}")
    IO.puts("Difference with /10 factor: #{diff_with_factor}")
    IO.puts("")
    
    # Determine which is closer
    if diff_without_factor < diff_with_factor do
      IO.puts("✓ WITHOUT /10 factor is closer to Skyfield value")
      IO.puts("  Relative error: #{(diff_without_factor / abs(skyfield_eq_eq_total)) * 100}%")
    else
      IO.puts("✓ WITH /10 factor is closer to Skyfield value")
      IO.puts("  Relative error: #{(diff_with_factor / abs(skyfield_eq_eq_total)) * 100}%")
    end
    
    IO.puts("")
    IO.puts("=== Additional Analysis ===")
    IO.puts("Factor of 10 ratio: #{eq_eq_without_factor / eq_eq_with_factor}")
    IO.puts("dpsi magnitude: #{abs(dpsi)}")
    IO.puts("cos(epsilon): #{:math.cos(epsilon)}")
    
    # Check if our dpsi might already be scaled
    expected_dpsi_from_skyfield = skyfield_eq_eq_total / :math.cos(epsilon)
    IO.puts("")
    IO.puts("Expected dpsi from Skyfield eq_eq: #{expected_dpsi_from_skyfield}")
    IO.puts("Our calculated dpsi: #{dpsi}")
    IO.puts("Ratio (our/expected): #{dpsi / expected_dpsi_from_skyfield}")
  end
  
  # Convert DateTime to Julian Date
  defp datetime_to_julian_date(datetime) do
    # Convert to Gregorian calendar day number
    year = datetime.year
    month = datetime.month
    day = datetime.day
    hour = datetime.hour
    minute = datetime.minute
    {microsecond, _precision} = datetime.microsecond
    second = datetime.second + microsecond / 1_000_000.0
    
    # Julian day calculation
    a = div(14 - month, 12)
    y = year + 4800 - a
    m = month + 12 * a - 3
    
    jdn = day + div(153 * m + 2, 5) + 365 * y + div(y, 4) - div(y, 100) + div(y, 400) - 32045
    
    # Add fractional day
    fraction = (hour - 12) / 24.0 + minute / 1440.0 + second / 86400.0
    
    jdn + fraction
  end
  
  # Calculate mean obliquity of ecliptic (IAU 2000A)
  defp calculate_mean_obliquity(t) do
    # Mean obliquity in arcseconds
    epsilon_0_arcsec = 84381.448 - 46.8150 * t - 0.00059 * t * t + 0.001813 * t * t * t
    
    # Convert to radians
    epsilon_0_arcsec * :math.pi() / (180.0 * 3600.0)
  end
end

# Run the debug test
DebugEquationOfEquinoxes.run()