# Check unit conversion
dpsi_rad = -0.00022574473900454788
epsilon_rad = 0.40903764357780753

# Calculate main term
main_term_rad = dpsi_rad * :math.cos(epsilon_rad)
IO.puts("Main term: #{main_term_rad} radians")

# Convert to hours using the standard formula
# 1 radian = 12/π hours (since 2π radians = 24 hours)
conversion_factor = 12.0 / :math.pi()
main_term_hours = main_term_rad * conversion_factor
IO.puts("Main term: #{main_term_hours} hours")
IO.puts("Conversion factor: #{conversion_factor}")

# Expected from Skyfield
expected_hours = -7.909984537946002e-05
IO.puts("Expected: #{expected_hours} hours")
IO.puts("Ratio: #{main_term_hours / expected_hours}")

# Check if the issue is in our dpsi value
skyfield_dpsi_rad = -0.00022574473900454788  # From Skyfield
our_dpsi_microasec = -46563157.87293507      # Our value in microarcsec
asec2rad = 4.84813681109535984270e-06
our_dpsi_rad = our_dpsi_microasec * 1.0e-6 * asec2rad
IO.puts("")
IO.puts("Skyfield dpsi: #{skyfield_dpsi_rad} radians")
IO.puts("Our dpsi: #{our_dpsi_rad} radians")
IO.puts("dpsi difference: #{our_dpsi_rad - skyfield_dpsi_rad}")