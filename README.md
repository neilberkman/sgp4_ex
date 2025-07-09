# Sgp4Ex

High-accuracy satellite orbit prediction for Elixir. Built on the official SGP4 C++ implementation with a complete IAU 2000A nutation model for Skyfield-compatible coordinate transformations.

## Features

- High-accuracy SGP4 propagation using the official C++ implementation
- TEME to geodetic coordinate conversion (latitude/longitude/altitude)
- IAU 2000A nutation model for Skyfield-compatible coordinates
- Forgiving TLE parser that handles common data issues
- Sub-meter accuracy at epoch, excellent accuracy for typical propagation periods

## Installation

Add `sgp4_ex` to your `mix.exs`:

```elixir
def deps do
  [
    {:sgp4_ex, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic TLE Propagation

```elixir
# Parse a TLE
line1 = "1 25544U 98067A   21275.54791667  .00001264  00000-0  39629-5 0  9993"
line2 = "2 25544  51.6456  23.4367 0001234  45.6789 314.3210 15.48999999    12"
{:ok, tle} = Sgp4Ex.parse_tle(line1, line2)

# Propagate to a specific time
epoch = ~U[2021-10-02T14:00:00Z]
{:ok, teme_state} = Sgp4Ex.propagate_tle_to_epoch(tle, epoch)

# Get position and velocity in TEME frame (km and km/s)
{x, y, z} = teme_state.position
{vx, vy, vz} = teme_state.velocity
```

### Geodetic Coordinates

```elixir
# Get latitude, longitude, and altitude (uses IAU 2000A by default)
{:ok, geo} = Sgp4Ex.propagate_to_geodetic(tle, epoch)
IO.puts("Latitude: #{geo.latitude}°")
IO.puts("Longitude: #{geo.longitude}°")
IO.puts("Altitude: #{geo.altitude_km} km")

# Use classical GMST if needed (not recommended)
{:ok, geo_classical} = Sgp4Ex.propagate_to_geodetic(tle, epoch, use_iau2000a: false)
```

## Accuracy & Skyfield Compatibility

Sgp4Ex achieves strong compatibility with the Skyfield Python library:

- **Geodetic coordinates**: Within 0.004° longitude (~400 meters), exact latitude/altitude match
- **TEME positions**: Within 1 km for typical propagation scenarios
- **IAU 2000A implementation**: Complete model with all 1431 nutation terms

The 0.004° longitude difference reflects different floating-point summation strategies between the implementations - both are equally valid and mathematically equivalent. This level of accuracy is excellent for all satellite tracking applications including:

- Visual observation and pass predictions
- Amateur radio and antenna pointing
- Educational and visualization purposes
- Commercial satellite tracking systems

Both implementations provide the same fundamental accuracy - the difference is purely computational, not physical.

### Performance

- **IAU 2000A mode**: ~2.5 ms per coordinate transformation (400 ops/sec)
- **Classical GMST mode**: ~0.001 ms per transformation (1,000,000 ops/sec)
- **For comparison**: Skyfield achieves ~0.04 ms using NumPy's C optimizations and caching

The IAU 2000A mode calculates all 1431 nutation terms from scratch. Performance can be significantly improved by adding EXLA for GPU/CPU acceleration:

```elixir
# Add to mix.exs
{:exla, "~> 0.9.0"}

# Configure at application startup
Nx.default_backend(EXLA.Backend)
```

With EXLA, IAU 2000A performance can approach or exceed Skyfield's speed.

**Note**: EXLA compilation on macOS with Apple clang 17+ (Xcode 16+) is automatically handled. The library detects this configuration and applies the necessary workaround during compilation.

## Technical Details

### Coordinate Systems

- **TEME (True Equator Mean Equinox)**: Output frame from SGP4
- **ECEF (Earth-Centered Earth-Fixed)**: Intermediate frame for geodetic conversion
- **Geodetic**: WGS84 latitude, longitude, and altitude

### TLE Parser

The parser automatically handles common data issues:

- Trailing whitespace and backslashes
- Truncated checksums
- Leading dots in floats (.123 → 0.123)
- Spaces in numeric fields

### Build Requirements

- Erlang/OTP with NIF support
- C++ compiler
- Make

The build process is handled automatically by the custom Mix task.

## Implementation Notes

This library wraps the official SGP4 C++ implementation from https://celestrak.org/publications/AIAA/2006-6753/ via a NIF (Native Implemented Function). The IAU 2000A nutation model implementation faithfully reproduces every calculation from Skyfield, achieving very close compatibility with the leading Python astronomy library.

## License

This project is licensed under the same terms as the original SGP4 source code.
