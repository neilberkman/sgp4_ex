# Sgp4Ex

`Sgp4Ex` is an elixir NIF wrapper for the SGP4 source code available at https://celestrak.org/publications/AIAA/2006-6753/ - it allows propagation of Two-Line Element sets (TLEs) to get TEME state vectors describing the position/velocity of satellites.

## Installation

`Sgp4Ex` can be installed by adding it to `mix.exs`:

```elixir
def deps do
  [
    {:sgp4_ex, "~> 0.1.0"}
  ]
end
```
