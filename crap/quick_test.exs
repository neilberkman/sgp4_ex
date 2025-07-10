#!/usr/bin/env mix run

line1 = "1 25544U 98067A   24138.55992426  .00020637  00000+0  36128-3 0  9999"
line2 = "2 25544  51.6390 204.9906 0003490  80.5715  50.0779 15.50382821453258"

{time, _result} = :timer.tc(fn -> 
  Sgp4Ex.SatelliteArray.propagate_to_geodetic([{line1, line2}], ~U[2024-05-18 12:00:00Z], 
    use_cache: false, use_batch_nif: false, use_gpu_coords: false)
end)

IO.puts("Single propagation: #{time/1000} ms")