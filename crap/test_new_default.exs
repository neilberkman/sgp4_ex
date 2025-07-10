#!/usr/bin/env mix run

line1 = "1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999"
line2 = "2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258"

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
datetime = ~U[2024-05-18 12:00:00Z]

# Test new default (should be GMST)
{default_time, _result} = :timer.tc(fn -> 
  Sgp4Ex.propagate_to_geodetic(tle, datetime)
end)
IO.puts("New default: #{default_time/1000} ms")

# Compare to Python Skyfield
python_time = 0.0866  # ms per propagation
speedup = python_time / (default_time/1000)
IO.puts("vs Python Skyfield: #{Float.round(speedup, 1)}x #{if speedup > 1, do: "faster", else: "slower"}")

# Test 100 propagations (equivalent to Python benchmark)
{time_100, _results} = :timer.tc(fn -> 
  Enum.map(1..100, fn _ ->
    Sgp4Ex.propagate_to_geodetic(tle, datetime)
  end)
end)

elixir_100_time = time_100 / 1000  # Convert to ms
python_100_time = 8.66  # Python's measured time for 100 propagations

IO.puts("\n100 propagations:")
IO.puts("Elixir: #{Float.round(elixir_100_time, 2)} ms")
IO.puts("Python: #{python_100_time} ms")
IO.puts("Speedup: #{Float.round(python_100_time / elixir_100_time, 1)}x faster than Python")