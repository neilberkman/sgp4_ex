# skyfield_parity: opt-in 0 ULP bit-exact test (mix test --include skyfield_parity)
# pending_nif: tests for ECEF/geodetic/GMST NIFs not yet in the current build
ExUnit.start(exclude: [:skyfield_parity, :pending_nif])
