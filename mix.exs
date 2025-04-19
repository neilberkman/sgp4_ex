defmodule Sgp4Ex.MixProject do
  use Mix.Project

  def project do
    [
      app: :sgp4_ex,
      version: "0.1.1",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:makesgp4] ++ Mix.compilers(),
      aliases: aliases(),
      description: "Elixir wrapper for Vallado's SGP4 propagator implementation",
      name: "Sgp4Ex",
      source_url: "https://github.com/jmcguigs/sgp4_ex",
      package: package()
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
    [{:ex_doc, "~> 0.14", only: :dev, runtime: false}]
  end

  defp package() do
    [
      name: "sgp4_ex",
      files: ["lib", "cpp_src", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["jmcguigs"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jmcguigs/sgp4_ex"}
    ]
  end
end
