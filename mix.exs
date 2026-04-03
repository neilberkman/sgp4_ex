defmodule Sgp4Ex.MixProject do
  use Mix.Project

  @version "0.1.2"

  def project do
    [
      app: :sgp4_ex,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:elixir_make] ++ Mix.compilers(),
      aliases: aliases(),
      description: "Elixir wrapper for Vallado's SGP4 propagator implementation",
      name: "Sgp4Ex",
      source_url: "https://github.com/jmcguigs/sgp4_ex",
      package: package(),
      # elixir_make specific config
      make_precompiler: {:nif, CCPrecompiler},
      make_precompiler_url:
        "https://github.com/neilberkman/sgp4_ex/releases/download/v#{@version}/@{artefact_filename}",
      make_precompiler_filename: "sgp4_nif",
      make_precompiler_priv_paths: ["sgp4_nif.*"],
      make_precompiler_unavailable_target: :compile
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Sgp4Ex.Application, []}
    ]
  end

  defp aliases do
    [
      compile: ["load_tasks", "compile"],
      load_tasks: &load_makesgp4/1
    ]
  end

  # need to pre-load the task to ensure it is available
  defp load_makesgp4(_) do
    Code.require_file("lib/mix/tasks/compile/makesgp4.ex")
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:elixir_make, "~> 0.6", runtime: false},
      {:cc_precompiler, "~> 0.1.10", runtime: false},
      {:quokka, "~> 2.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      name: "sgp4_ex",
      files: [
        "lib",
        "cpp_src",
        "sofa",
        "mix.exs",
        "README.md",
        "LICENSE",
        "SOFA_LICENSE.md",
        "Makefile",
        "checksum.exs"
      ],
      maintainers: ["jmcguigs"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jmcguigs/sgp4_ex"}
    ]
  end
end
