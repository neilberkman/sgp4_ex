#!/usr/bin/env elixir

# Debug step by step against Skyfield calculation

jd_tt = 2460385.000800741
t = (jd_tt - 2451545.0) / 36525.0

IO.puts("=== STEP BY STEP DEBUG ===")
IO.puts("T: #{t}")

# Test just the first few terms manually
# First term: multiplier [0,0,0,0,1], longitude coeff [-172064161.0, -174666.0, 33386.0]

# Get fundamental arguments (using internal constants)
fa0 = [3.154384999847899, 2.357551718265301, 1.6280158027288272, 5.198471222772339, 2.182438624381695]
fa1 = [628_307_584_999.0, 8_399_684.6073, 8_433_463.1576, 7_771_374.8964, -33.86238]

# Calculate first 5 fundamental arguments
fund_args = Enum.zip(fa0, fa1) 
            |> Enum.map(fn {c0, c1} -> c0 + c1 * t end)
            |> Enum.map(fn arg -> :math.fmod(arg, 1_296_000.0) * 4.848136811095359935899141e-6 end)

IO.puts("First 5 fund args: #{inspect(fund_args)}")

# First term: [0,0,0,0,1] dot fund_args = fund_args[4]  
first_arg = Enum.at(fund_args, 4)
IO.puts("First arg: #{first_arg}")

# Calculate sin and cos
sin_first = :math.sin(first_arg)
cos_first = :math.cos(first_arg)
IO.puts("Sin: #{sin_first}, Cos: #{cos_first}")

# First longitude term: sin*(-172064161) + sin*(-174666)*t + cos*(33386)
first_dpsi = sin_first * (-172064161.0) + sin_first * (-174666.0) * t + cos_first * 33386.0
IO.puts("First dpsi contribution: #{first_dpsi}")

# Expected from Skyfield: this should be the dominant term
IO.puts("Expected dominant contribution to raw dpsi: ~#{first_dpsi}")

# Now let me check what my tensor calculation gives for ALL terms
{dpsi_all, _deps_all} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
asec2rad = 4.848136811095359935899141e-6
dpsi_raw_all = dpsi_all / (1.0e-7 * asec2rad)
IO.puts("My total raw dpsi: #{dpsi_raw_all}")
IO.puts("Skyfield total raw dpsi: -46563194.85207441")
IO.puts("Ratio: #{dpsi_raw_all / -46563194.85207441}")