# Automatically fix EXLA compilation on macOS with Apple clang 17+
# Only apply wrapper when gcc is NOT available (i.e., we'll be using clang)

check_and_apply_clang_wrapper = fn ->
  # Only apply wrapper when using clang
  case System.cmd("clang", ["--version"]) do
    {output, 0} ->
      if String.contains?(output, "Apple clang version") do
        case Regex.run(~r/Apple clang version (\d+)\./, output) do
          [_, version_str] ->
            {version, _} = Integer.parse(version_str)

            if version >= 17 do
              IO.puts(
                "🔧 Detected Apple clang #{version} - applying EXLA compilation workaround..."
              )

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
end

case :os.type() do
  {:unix, :darwin} ->
    # Check if user already set CXX
    existing_cxx = System.get_env("CXX")

    if existing_cxx do
      # User explicitly set CXX, respect their choice
      IO.puts("ℹ️  Using user-specified CXX=#{existing_cxx}")

      # If they chose clang, they might need the wrapper
      if existing_cxx in ["clang", "clang++", "c++"] do
        # Check clang version and apply wrapper if needed
        check_and_apply_clang_wrapper.()
      end
    else
      # No CXX set, check if gcc is available (same logic as Makefile)
      gcc_versions = [15, 14, 13, 12, 11]

      gcc_found =
        Enum.find_value(gcc_versions, fn ver ->
          case System.cmd("which", ["g++-#{ver}"], stderr_to_stdout: true) do
            {_path, 0} -> "g++-#{ver}"
            _ -> nil
          end
        end)

      if gcc_found do
        # When gcc is available, set it as CXX for EXLA to use
        # This ensures both NIFs and EXLA use the same compiler
        System.put_env("CXX", gcc_found)
        IO.puts("ℹ️  Found #{gcc_found} - setting as CXX for EXLA")
      else
        # No gcc available, will use system default (likely clang)
        check_and_apply_clang_wrapper.()
      end
    end

  _ ->
    :ok
end
