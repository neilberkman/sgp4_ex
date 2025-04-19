defmodule Mix.Tasks.Hello do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    IO.puts("Hello, world!")
  end
end
