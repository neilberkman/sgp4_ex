IO.puts("EXLA available: #{Code.ensure_loaded?(EXLA)}")
if Code.ensure_loaded?(EXLA) do
  IO.puts("EXLA version: #{Application.spec(:exla, :vsn)}")
else
  IO.puts("EXLA not available")
end