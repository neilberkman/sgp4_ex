# Automatically fix EXLA compilation on macOS with Apple clang 17+
case :os.type() do
  {:unix, :darwin} ->
    # Check clang version
    case System.cmd("clang", ["--version"]) do
      {output, 0} ->
        if String.contains?(output, "Apple clang version") do
          case Regex.run(~r/Apple clang version (\d+)\./, output) do
            [_, version_str] ->
              {version, _} = Integer.parse(version_str)
              
              if version >= 17 do
                IO.puts("🔧 Detected Apple clang #{version} - applying EXLA compilation workaround...")
                
                wrapper_path = Path.join([File.cwd!(), ".exla_cxx_wrapper.sh"])
                
                # Create wrapper script
                File.write!(wrapper_path, """
                #!/bin/bash
                # Auto-generated wrapper for EXLA compilation on macOS with clang 17+
                exec c++ "$@" -Wno-error=missing-template-arg-list-after-template-kw
                """)
                
                File.chmod!(wrapper_path, 0o755)
                
                # Set CXX environment variable
                System.put_env("CXX", wrapper_path)
                
                IO.puts("✅ Applied compiler wrapper for EXLA")
              end

            _ ->
              :ok
          end
        end

      _ ->
        :ok
    end

  _ ->
    :ok
end