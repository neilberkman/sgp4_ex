defmodule Sgp4Ex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    import Cachex.Spec

    children = [
      # Cachex-based satellite cache for improved performance  
      {Cachex,
       [
         :sgp4_satellite_cache,
         [
           limit: 1000,
           hooks: [
             hook(module: Cachex.Stats)
           ]
         ]
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sgp4Ex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
