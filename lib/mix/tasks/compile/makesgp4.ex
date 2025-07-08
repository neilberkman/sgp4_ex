defmodule Mix.Tasks.Compile.Makesgp4 do
  use Mix.Task.Compiler

  @shortdoc "Compiles C++ code for SGP4 NIF using Makefile"

  @impl Mix.Task.Compiler
  def run(_args) do
    # Define the output directory for the NIF
    priv_dir = Path.join([Mix.Project.build_path(), "priv"])
    nif_so = Path.join(priv_dir, "sgp4_nif.so")

    # Ensure the priv directory exists
    File.mkdir_p!(priv_dir)

    # Run `make` and capture the output
    {output, exit_code} = System.cmd("make", [], stderr_to_stdout: true)

    case exit_code do
      0 ->
        Mix.shell().info(output)
        # After successful compilation, copy the NIF to the priv directory
        # This assumes the Makefile places the compiled NIF in a known location, e.g., "priv/sgp4_nif.so"
        source_nif = Path.join(File.cwd!(), "priv/sgp4_nif.so")
        File.cp!(source_nif, nif_so)
        {:ok, [nif_so]}

      _ ->
        Mix.shell().error("Makefile compilation failed with exit code #{exit_code}:\n#{output}")
        {:error, :make_failed}
    end
  end

  @impl Mix.Task.Compiler
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
