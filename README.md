# Sgp4Ex

Elixir NIF wrapper for the SGP4 satellite orbit propagator with a native TEME→GCRS coordinate transformation that achieves bit-exact (0 ULP) parity with [Skyfield](https://rhodesmill.org/skyfield/).

Based on the [Vallado C++ SGP4 implementation](https://celestrak.org/publications/AIAA/2006-6753/).

## Installation

```elixir
def deps do
  [{:sgp4_ex, "~> 0.1.0"}]
end
```

Precompiled NIFs are available for Linux (x86_64, ARM64) and macOS (Apple Silicon). Falls back to compiling from source if no precompiled binary is available (requires a C/C++ compiler and Make).

## Usage

### Parse and propagate a TLE

```elixir
line1 = "1 25544U 98067A   18184.80969102  .00001614  00000-0  31745-4 0  9993"
line2 = "2 25544  51.6414 295.8524 0003435 262.6267 204.2868 15.54005638121106"

{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)
{:ok, teme_state} = Sgp4Ex.propagate_tle_to_datetime(tle, ~U[2018-07-04 00:00:00Z])

# TEME position (km) and velocity (km/s)
{x, y, z} = teme_state.position
{vx, vy, vz} = teme_state.velocity
```

### Convert TEME to GCRS (inertial frame)

```elixir
gcrs = Sgp4Ex.teme_to_gcrs(teme_state, ~U[2018-07-04 00:00:00Z])
{gx, gy, gz} = gcrs.position
{gvx, gvy, gvz} = gcrs.velocity
```

The TEME→GCRS transformation includes IAU2000A nutation (1365 terms), IAU2006 precession, frame bias, and precise time scale conversions (UTC→TAI→TT→TDB→UT1). It produces IEEE 754 bit-identical output to Skyfield on all tested platforms.

### Forgiving TLE parser

The parser handles common data quality issues:
- Trailing whitespace and backslashes
- Truncated checksums
- Leading dots in floats (`.123` → `0.123`)
- Spaces in numeric fields

## License

Licensed under the same terms as the original SGP4 source code.
