defmodule Sgp4Ex.MixProject do
  use Mix.Project

  def project do
    [
      app: :sgp4_ex,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:makesgp4] ++ Mix.compilers(),
      aliases: aliases()
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
