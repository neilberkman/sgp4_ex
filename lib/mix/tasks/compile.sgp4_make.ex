defmodule Mix.Tasks.Compile.Sgp4Make do
  use Mix.Task.Compiler

  @shortdoc "Compiles C++ code for SGP4 NIF using Makefile"

  @impl true
  def run(_args) do
    # Run `make` in the project root
    case System.cmd("make", [], stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        :ok

      {output, exit_code} ->
        Mix.shell().error("Makefile compilation failed with exit code #{exit_code}:\n#{output}")
        {:error, :make_failed}
    end
  end

  @impl true
  def clean do
    # Run `make clean`
    case System.cmd("make", ["clean"], stderr_to_stdout: true) do
      {output, 0} ->
        Mix.shell().info(output)
        :ok

      {output, exit_code} ->
        Mix.shell().error("Makefile clean failed with exit code #{exit_code}:\n#{output}")
        {:error, :make_clean_failed}
    end
  end
end
