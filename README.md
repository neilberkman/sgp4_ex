# Sgp4Ex

`Sgp4Ex` is an Elixir NIF wrapper for the SGP4 source code available at https://celestrak.org/publications/AIAA/2006-6753/ - it allows propagation of Two-Line Element sets (TLEs) to get TEME state vectors describing the position/velocity of satellites.

## Features

- High-accuracy SGP4 propagation using the official C++ implementation
- Forgiving TLE parser that handles common data issues
- TEME to geodetic coordinate conversion (latitude/longitude/altitude)
- Sub-meter accuracy at epoch, maintains excellent accuracy for typical propagation periods

## Installation

`Sgp4Ex` can be installed by adding it to `mix.exs`:

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
# Get latitude, longitude, and altitude
{:ok, geo} = Sgp4Ex.propagate_to_geodetic(tle, epoch)
IO.puts("Latitude: #{geo.latitude}°")
IO.puts("Longitude: #{geo.longitude}°")
IO.puts("Altitude: #{geo.altitude_km} km")
```

### Forgiving TLE Parser

The TLE parser automatically handles common data issues:
- Trailing whitespace and backslashes
- Truncated checksums
- Leading dots in floats (.123 → 0.123)
- Spaces in numeric fields

## Technical Details

### Coordinate Systems

- **TEME (True Equator Mean Equinox)**: Output frame from SGP4
- **ECEF (Earth-Centered Earth-Fixed)**: Intermediate frame for geodetic conversion
- **Geodetic**: WGS84 latitude, longitude, and altitude

The implementation uses the classical IAU 1982 model for Greenwich Mean Sidereal Time (GMST). This differs from modern implementations like Skyfield by approximately 0.536° in longitude due to the Equation of the Equinoxes (the difference between mean and apparent sidereal time).

### Build Requirements

- Erlang/OTP with NIF support
- C++ compiler
- Make

The build process is handled automatically by the custom Mix task.

## License

This project is licensed under the same terms as the original SGP4 source code.
