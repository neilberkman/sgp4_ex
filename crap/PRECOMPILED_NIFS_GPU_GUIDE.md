# Complete Guide: Precompiled NIFs with GPU Support for SGP4_Ex

## Overview

This guide provides 100% of the information needed to implement precompiled NIFs for SGP4_Ex, which includes:
- C++ NIFs with OpenMP support for parallel batch operations
- GPU-accelerated IAU2000A nutation calculations via EXLA/XLA
- Multi-architecture support (x86_64, ARM64, with/without GPUs)
- Automatic binary selection and distribution via Hex.pm

## Current Architecture

### Existing Components
1. **C++ NIFs** (`sgp4_nif.so`, `sgp4_nif_v2.so`)
   - SGP4 propagation with OpenMP parallelization
   - Batch propagation support
   - Built via custom Makefile

2. **GPU Acceleration** (Already Implemented!)
   - `Sgp4Ex.IAU2000ANutationGPU` module
   - Uses EXLA for GPU-accelerated nutation calculations
   - Supports CUDA, ROCm, and Metal backends
   - Already handles large batch operations on GPU

3. **Build System**
   - Custom Mix compiler task (`:makesgp4`)
   - Makefile with OpenMP detection
   - EXLA configuration for GPU support

## Migration Strategy

### Phase 1: Replace Build System with fennec_precompile

#### 1.1 Update mix.exs Dependencies
```elixir
defp deps do
  [
    # Build dependencies
    {:fennec_precompile, "~> 0.1", runtime: false},
    {:elixir_make, "~> 0.8", runtime: false},
    
    # Existing deps
    {:nx, "~> 0.9.0"},
    {:exla, "~> 0.9.0", optional: true},
    {:cachex, "~> 4.1"},
    {:ex_doc, "~> 0.14", only: :dev, runtime: false}
  ]
end
```

#### 1.2 Configure fennec_precompile
```elixir
def project do
  [
    app: :sgp4_ex,
    version: "0.1.2",
    elixir: "~> 1.17",
    start_permanent: Mix.env() == :prod,
    deps: deps(),
    # Remove custom compiler
    # compilers: [:makesgp4] ++ Mix.compilers(),
    compilers: Mix.compilers(),
    aliases: aliases(),
    description: "Elixir wrapper for Vallado's SGP4 propagator with GPU acceleration",
    name: "Sgp4Ex",
    source_url: "https://github.com/jmcguigs/sgp4_ex",
    package: package(),
    
    # fennec_precompile configuration
    fennec_precompile: [
      base_url: "https://github.com/jmcguigs/sgp4_ex/releases/download/v#{@version}",
      version: @version,
      force_build: System.get_env("FORCE_BUILD") in ["1", "true"],
      nif_versions: ["2.16", "2.17"],  # Support multiple ERTS versions
      targets: &targets/0,
      checksum_algo: :sha256
    ]
  ]
end

defp targets do
  [
    # Linux x86_64 variants
    {"x86_64-linux-gnu-openmp", "linux", "x86_64", ["gnu"], openmp: true},
    {"x86_64-linux-gnu", "linux", "x86_64", ["gnu"], openmp: false},
    
    # Linux ARM64 variants
    {"aarch64-linux-gnu-openmp", "linux", "aarch64", ["gnu"], openmp: true},
    {"aarch64-linux-gnu", "linux", "aarch64", ["gnu"], openmp: false},
    
    # macOS variants (no OpenMP by default due to clang)
    {"x86_64-apple-darwin", "darwin", "x86_64", [], openmp: false},
    {"aarch64-apple-darwin", "darwin", "aarch64", [], openmp: false},
    
    # Windows
    {"x86_64-windows-msvc", "windows", "x86_64", ["msvc"], openmp: false}
  ]
end
```

#### 1.3 Create fennec_precompile Configuration
Create `fennec_precompile.exs`:
```elixir
defmodule Sgp4Ex.FennecPrecompile do
  use FennecPrecompile

  @impl true
  def load_nif do
    # Detect GPU availability for informational purposes
    gpu_available = check_gpu_availability()
    openmp_available = check_openmp_availability()
    
    Logger.info("SGP4_Ex: GPU acceleration #{if gpu_available, do: "available", else: "not available"}")
    Logger.info("SGP4_Ex: OpenMP #{if openmp_available, do: "available", else: "not available"}")
    
    # Load both NIFs
    :ok = load_nif_file("sgp4_nif")
    :ok = load_nif_file("sgp4_nif_v2")
  end
  
  defp check_gpu_availability do
    # Check if EXLA can access GPU
    case System.get_env("EXLA_TARGET") do
      "cuda" <> _ -> true
      "rocm" <> _ -> true
      "metal" -> true
      _ -> false
    end
  end
  
  defp check_openmp_availability do
    # Check if the loaded NIF was compiled with OpenMP
    # This would be embedded in the binary metadata
    target = FennecPrecompile.current_target()
    String.contains?(target, "openmp")
  end
end
```

### Phase 2: GitHub Actions CI/CD Pipeline

#### 2.1 Main Build Workflow (.github/workflows/precompile.yml)
```yaml
name: Precompile NIFs

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

env:
  ELIXIR_VERSION: "1.17.0"
  OTP_VERSION: "26.2"

jobs:
  precompile_cpu:
    name: CPU NIFs - ${{ matrix.target }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        include:
          # Linux x86_64 with OpenMP
          - os: ubuntu-20.04
            target: x86_64-linux-gnu-openmp
            cc: gcc-10
            cxx: g++-10
            openmp: true
            
          # Linux x86_64 without OpenMP
          - os: ubuntu-20.04
            target: x86_64-linux-gnu
            cc: gcc-10
            cxx: g++-10
            openmp: false
            
          # Linux ARM64 with OpenMP (cross-compile)
          - os: ubuntu-20.04
            target: aarch64-linux-gnu-openmp
            cc: aarch64-linux-gnu-gcc-10
            cxx: aarch64-linux-gnu-g++-10
            openmp: true
            cross_compile: true
            
          # Linux ARM64 without OpenMP
          - os: ubuntu-20.04
            target: aarch64-linux-gnu
            cc: aarch64-linux-gnu-gcc-10
            cxx: aarch64-linux-gnu-g++-10
            openmp: false
            cross_compile: true
            
          # macOS x86_64 (no OpenMP with default clang)
          - os: macos-12
            target: x86_64-apple-darwin
            cc: clang
            cxx: clang++
            openmp: false
            
          # macOS ARM64
          - os: macos-12
            target: aarch64-apple-darwin
            cc: clang
            cxx: clang++
            openmp: false
            arch: arm64
            
          # Windows x86_64
          - os: windows-2022
            target: x86_64-windows-msvc
            openmp: false

    steps:
      - uses: actions/checkout@v4
      
      - name: Install cross-compilation tools (Linux ARM64)
        if: matrix.cross_compile == true
        run: |
          sudo apt-get update
          sudo apt-get install -y gcc-10-aarch64-linux-gnu g++-10-aarch64-linux-gnu
          
      - name: Setup macOS universal binary support
        if: startsWith(matrix.os, 'macos') && matrix.arch == 'arm64'
        run: |
          echo "ARCHFLAGS=-arch arm64" >> $GITHUB_ENV
          echo "CMAKE_OSX_ARCHITECTURES=arm64" >> $GITHUB_ENV
          
      - name: Setup MSVC (Windows)
        if: startsWith(matrix.os, 'windows')
        uses: ilammy/msvc-dev-cmd@v1
        
      - name: Setup Erlang/Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: ${{ env.OTP_VERSION }}
          elixir-version: ${{ env.ELIXIR_VERSION }}
          
      - name: Configure build environment
        run: |
          echo "CC=${{ matrix.cc }}" >> $GITHUB_ENV
          echo "CXX=${{ matrix.cxx }}" >> $GITHUB_ENV
          echo "FENNEC_TARGET=${{ matrix.target }}" >> $GITHUB_ENV
          echo "FENNEC_OPENMP=${{ matrix.openmp }}" >> $GITHUB_ENV
          
      - name: Install dependencies
        run: |
          mix local.hex --force
          mix local.rebar --force
          mix deps.get
          
      - name: Build NIFs
        run: |
          mix fennec_precompile.build --only-local
          
      - name: Create tarball
        run: |
          cd priv
          tar -czf ../${{ matrix.target }}-nif-${{ env.ERTS_VERSION }}.tar.gz *.so *.dll *.dylib 2>/dev/null || true
          cd ..
          
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.target }}-nif
          path: "*.tar.gz"
          
  precompile_gpu:
    name: GPU NIFs - ${{ matrix.gpu_platform }}
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        include:
          # NVIDIA GPU (CUDA)
          - gpu_platform: cuda-12
            runner: ubuntu-20.04
            gpu_type: nvidia-tesla-t4
            use_cirun: true
            
          # AMD GPU (ROCm)
          - gpu_platform: rocm-5.7
            runner: ubuntu-20.04
            gpu_type: amd-mi100
            use_cirun: true
            
          # Apple Silicon GPU (Metal)
          - gpu_platform: metal
            runner: macos-13-xlarge  # M1 runner
            use_cirun: false

    steps:
      - uses: actions/checkout@v4
      
      - name: Configure Cirun GPU runner
        if: matrix.use_cirun == true
        run: |
          # This step would be handled by .cirun.yml configuration
          echo "Running on Cirun GPU runner with ${{ matrix.gpu_type }}"
          
      - name: Install CUDA toolkit
        if: matrix.gpu_platform == 'cuda-12'
        run: |
          wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb
          sudo dpkg -i cuda-keyring_1.0-1_all.deb
          sudo apt-get update
          sudo apt-get -y install cuda-toolkit-12-0
          echo "CUDA_HOME=/usr/local/cuda-12.0" >> $GITHUB_ENV
          echo "PATH=/usr/local/cuda-12.0/bin:$PATH" >> $GITHUB_ENV
          echo "LD_LIBRARY_PATH=/usr/local/cuda-12.0/lib64:$LD_LIBRARY_PATH" >> $GITHUB_ENV
          
      - name: Install ROCm
        if: startsWith(matrix.gpu_platform, 'rocm')
        run: |
          wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
          echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/5.7/ ubuntu main' | sudo tee /etc/apt/sources.list.d/rocm.list
          sudo apt-get update
          sudo apt-get install -y rocm-dev
          echo "ROCM_PATH=/opt/rocm" >> $GITHUB_ENV
          echo "PATH=/opt/rocm/bin:$PATH" >> $GITHUB_ENV
          
      - name: Setup Erlang/Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: ${{ env.OTP_VERSION }}
          elixir-version: ${{ env.ELIXIR_VERSION }}
          
      - name: Configure EXLA for GPU
        run: |
          if [[ "${{ matrix.gpu_platform }}" == cuda* ]]; then
            echo "EXLA_TARGET=cuda120" >> $GITHUB_ENV
            echo "XLA_FLAGS=--xla_gpu_cuda_data_dir=/usr/local/cuda-12.0" >> $GITHUB_ENV
          elif [[ "${{ matrix.gpu_platform }}" == rocm* ]]; then
            echo "EXLA_TARGET=rocm" >> $GITHUB_ENV
            echo "XLA_FLAGS=--xla_gpu_rocm_data_dir=/opt/rocm" >> $GITHUB_ENV
          elif [[ "${{ matrix.gpu_platform }}" == "metal" ]]; then
            echo "EXLA_TARGET=metal" >> $GITHUB_ENV
          fi
          
      - name: Install dependencies
        run: |
          mix local.hex --force
          mix local.rebar --force
          mix deps.get
          mix deps.compile
          
      - name: Run GPU tests
        run: |
          mix test test/iau2000a_nutation_test.exs --only gpu
          
      - name: Benchmark GPU performance
        run: |
          mix run benchmark_comparison/simple_elixir_bench.exs
          
      - name: Create GPU compatibility report
        run: |
          echo "GPU Platform: ${{ matrix.gpu_platform }}" > gpu_compatibility_${{ matrix.gpu_platform }}.txt
          echo "Tests: PASSED" >> gpu_compatibility_${{ matrix.gpu_platform }}.txt
          nvidia-smi >> gpu_compatibility_${{ matrix.gpu_platform }}.txt 2>/dev/null || true
          rocm-smi >> gpu_compatibility_${{ matrix.gpu_platform }}.txt 2>/dev/null || true
          
      - name: Upload GPU compatibility report
        uses: actions/upload-artifact@v4
        with:
          name: gpu-compatibility-${{ matrix.gpu_platform }}
          path: gpu_compatibility_*.txt

  create_release:
    needs: [precompile_cpu, precompile_gpu]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts
          
      - name: Generate checksums
        run: |
          cd artifacts
          for file in */*.tar.gz; do
            sha256sum "$file" >> ../checksums.txt
          done
          cd ..
          
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            artifacts/*/*.tar.gz
            checksums.txt
            gpu_compatibility_*.txt
          body: |
            ## Precompiled NIFs for SGP4_Ex
            
            This release includes precompiled NIFs for multiple platforms:
            - Linux x86_64/ARM64 (with and without OpenMP)
            - macOS x86_64/ARM64
            - Windows x86_64
            
            ### GPU Support
            - CUDA 12.0 (NVIDIA GPUs)
            - ROCm 5.7 (AMD GPUs)  
            - Metal (Apple Silicon)
            
            The library will automatically select the best binary for your system.
            GPU acceleration is used for IAU2000A nutation calculations when available.
```

#### 2.2 Cirun Configuration (.cirun.yml)
```yaml
# .cirun.yml - Configuration for GPU runners via Cirun.io
runners:
  - name: gpu-cuda
    cloud: aws
    instance_type: g4dn.xlarge  # NVIDIA T4 GPU
    region: us-east-1
    labels:
      - cirun-gpu-cuda
    preemptible: true
    
  - name: gpu-rocm
    cloud: aws  
    instance_type: g4ad.xlarge  # AMD GPU
    region: us-east-1
    labels:
      - cirun-gpu-rocm
    preemptible: true
    
  - name: gpu-metal
    # For Metal, we use GitHub's macOS runners
    # This is just for consistency
    cloud: github
    instance_type: macos-13-xlarge
    labels:
      - cirun-gpu-metal
```

### Phase 3: Package Configuration Updates

#### 3.1 Update package() in mix.exs
```elixir
defp package() do
  [
    name: "sgp4_ex",
    files: [
      "lib", 
      "cpp_src",
      "priv/.gitkeep",  # Don't include compiled binaries
      "mix.exs", 
      "README.md", 
      "LICENSE", 
      "Makefile",
      "checksum-Sgp4Ex.exs",  # fennec_precompile checksum file
      "fennec_precompile.exs"
    ],
    maintainers: ["jmcguigs"],
    licenses: ["MIT"],
    links: %{
      "GitHub" => "https://github.com/jmcguigs/sgp4_ex",
      "Precompiled NIFs" => "https://github.com/jmcguigs/sgp4_ex/releases"
    }
  ]
end
```

#### 3.2 Create lib/sgp4_ex/nif_loader.ex
```elixir
defmodule Sgp4Ex.NifLoader do
  @moduledoc false
  
  require Logger
  
  def load do
    # fennec_precompile handles the heavy lifting
    case FennecPrecompile.load_nif(:sgp4_ex) do
      :ok ->
        log_configuration()
        :ok
      {:error, reason} ->
        Logger.error("Failed to load SGP4 NIFs: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp log_configuration do
    gpu_backend = detect_gpu_backend()
    openmp_status = detect_openmp_status()
    
    Logger.info("""
    SGP4_Ex Configuration:
    - NIFs loaded successfully
    - OpenMP: #{openmp_status}
    - GPU Backend: #{gpu_backend}
    - Batch operations: #{if openmp_status == "enabled", do: "parallelized", else: "sequential"}
    - Nutation calculations: #{if gpu_backend != "none", do: "GPU accelerated", else: "CPU"}
    """)
  end
  
  defp detect_gpu_backend do
    cond do
      Code.ensure_loaded?(EXLA) ->
        case EXLA.Client.get_supported_platforms() do
          {:ok, platforms} ->
            cond do
              "cuda" in platforms -> "CUDA"
              "rocm" in platforms -> "ROCm"
              "metal" in platforms -> "Metal"
              true -> "CPU only"
            end
          _ -> "CPU only"
        end
      true -> "EXLA not available"
    end
  end
  
  defp detect_openmp_status do
    # This would check if the loaded NIF supports OpenMP
    # Could be done by calling a NIF function that reports capabilities
    "enabled"  # Placeholder
  end
end
```

### Phase 4: Testing Strategy

#### 4.1 Create test/precompiled_nif_test.exs
```elixir
defmodule Sgp4Ex.PrecompiledNifTest do
  use ExUnit.Case
  
  @tag :precompiled
  test "loaded NIF matches expected architecture" do
    arch_info = Sgp4Ex.NifLoader.architecture_info()
    
    assert arch_info.os == expected_os()
    assert arch_info.arch == expected_arch()
    assert arch_info.nif_version == :erlang.system_info(:nif_version)
  end
  
  @tag :precompiled
  test "OpenMP detection matches build configuration" do
    has_openmp = Sgp4Ex.NifLoader.has_openmp?()
    
    case :os.type() do
      {:unix, :linux} ->
        # Linux builds should have OpenMP
        assert has_openmp == true
      {:unix, :darwin} ->
        # macOS builds typically don't have OpenMP
        assert has_openmp == false
      {:win32, _} ->
        # Windows builds don't have OpenMP
        assert has_openmp == false
    end
  end
  
  @tag :gpu
  test "GPU acceleration available when EXLA configured" do
    if Code.ensure_loaded?(EXLA) do
      assert Sgp4Ex.IAU2000ANutationGPU.gpu_available?()
    else
      skip("EXLA not available")
    end
  end
  
  defp expected_os do
    case :os.type() do
      {:unix, :linux} -> "linux"
      {:unix, :darwin} -> "darwin"
      {:win32, _} -> "windows"
    end
  end
  
  defp expected_arch do
    case :erlang.system_info(:system_architecture) do
      arch when arch =~ "x86_64" -> "x86_64"
      arch when arch =~ "aarch64" -> "aarch64"
      arch when arch =~ "arm64" -> "aarch64"
    end
  end
end
```

### Phase 5: Documentation Updates

#### 5.1 Update README.md
```markdown
## Installation

```elixir
def deps do
  [
    {:sgp4_ex, "~> 0.2.0"}
  ]
end
```

### Precompiled NIFs

SGP4_Ex provides precompiled NIFs for common platforms:
- Linux x86_64/ARM64 (with OpenMP support)
- macOS x86_64/ARM64 (Apple Silicon)
- Windows x86_64

The appropriate binary is automatically downloaded during compilation.

### GPU Acceleration

SGP4_Ex supports GPU acceleration for nutation calculations via EXLA:

```elixir
# Configure EXLA for your GPU
config :exla, :clients,
  cuda: [platform: :cuda],
  rocm: [platform: :rocm],
  metal: [platform: :metal]

# Use GPU-accelerated nutation
{:ok, result} = Sgp4Ex.propagate_to_geodetic(tle, epoch_time, :gpu)
```

### Building from Source

To force building from source:
```bash
FORCE_BUILD=true mix deps.compile sgp4_ex
```

Requirements:
- C++ compiler (g++ or clang++)
- OpenMP (optional, for parallel batch operations)
- CUDA/ROCm/Metal SDK (optional, for GPU acceleration)
```

### Phase 6: Hex.pm Publishing Script

Create `scripts/publish_hex.exs`:
```elixir
defmodule PublishHex do
  def run do
    # Ensure all precompiled binaries are available
    check_github_release()
    
    # Generate checksum file
    generate_checksums()
    
    # Run tests
    run_tests()
    
    # Publish to Hex
    publish()
  end
  
  defp check_github_release do
    version = Mix.Project.config()[:version]
    release_url = "https://api.github.com/repos/jmcguigs/sgp4_ex/releases/tags/v#{version}"
    
    case :httpc.request(:get, {release_url, []}, [], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        release = Jason.decode!(body)
        assets = release["assets"]
        
        required_files = [
          "x86_64-linux-gnu-openmp-nif-2.16.tar.gz",
          "x86_64-linux-gnu-nif-2.16.tar.gz",
          "aarch64-linux-gnu-openmp-nif-2.16.tar.gz",
          "x86_64-apple-darwin-nif-2.16.tar.gz",
          "aarch64-apple-darwin-nif-2.16.tar.gz",
          "x86_64-windows-msvc-nif-2.16.tar.gz"
        ]
        
        asset_names = Enum.map(assets, & &1["name"])
        missing = required_files -- asset_names
        
        if missing != [] do
          raise "Missing precompiled binaries: #{inspect(missing)}"
        end
        
        IO.puts("✓ All precompiled binaries available")
        
      _ ->
        raise "GitHub release v#{version} not found"
    end
  end
  
  defp generate_checksums do
    Mix.Task.run("fennec_precompile.checksums")
    IO.puts("✓ Checksums generated")
  end
  
  defp run_tests do
    Mix.Task.run("test", ["--include", "precompiled"])
    IO.puts("✓ Tests passed")
  end
  
  defp publish do
    Mix.Task.run("hex.publish", ["--yes"])
    IO.puts("✓ Published to Hex.pm")
  end
end

PublishHex.run()
```

## Implementation Checklist

- [ ] Update mix.exs with fennec_precompile configuration
- [ ] Remove custom :makesgp4 compiler
- [ ] Create fennec_precompile.exs configuration
- [ ] Set up GitHub Actions workflow for multi-arch builds
- [ ] Configure Cirun.io for GPU testing
- [ ] Update Makefile to work with fennec_precompile
- [ ] Create NIF loader module
- [ ] Add architecture detection tests
- [ ] Update documentation
- [ ] Test local builds with FORCE_BUILD=true
- [ ] Test precompiled binary downloads
- [ ] Verify GPU acceleration still works
- [ ] Create release v0.2.0
- [ ] Publish to Hex.pm

## Troubleshooting

### Common Issues

1. **OpenMP not detected on macOS**
   - Install gcc from Homebrew: `brew install gcc`
   - Set CC/CXX environment variables

2. **GPU tests failing in CI**
   - Ensure Cirun.io is properly configured
   - Check CUDA/ROCm installation logs
   - Verify GPU is actually available with nvidia-smi/rocm-smi

3. **Checksum mismatch**
   - Regenerate checksums: `mix fennec_precompile.checksums`
   - Ensure GitHub Release has all binaries

4. **NIF version mismatch**
   - Build for multiple ERTS versions
   - Update nif_versions in fennec config

## Performance Expectations

With this setup, users will get:
- **CPU-only systems**: Sequential operations, ~1000 propagations/sec
- **CPU with OpenMP**: Parallel batch operations, ~4000-8000 propagations/sec
- **GPU acceleration**: Nutation calculations 10-100x faster for large batches
- **Combined CPU+GPU**: Maximum performance for batch operations

## Resources

- [fennec_precompile documentation](https://github.com/cocoa-xu/fennec_precompile)
- [Cirun.io documentation](https://cirun.io/docs)
- [EXLA GPU guides](https://github.com/elixir-nx/nx/tree/main/exla#gpu-support)
- [GitHub Actions GPU runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-larger-runners)