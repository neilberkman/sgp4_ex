# GPU CUDA Success Guide - The ONLY Working Method

## Starting Point
- **Instance**: GCP g2-standard-4 with NVIDIA L4
- **Base Image**: Deep Learning VM with PyTorch 2.4 and CUDA 12.4 pre-installed
- **Region**: us-central1-a

## Required Versions (NON-NEGOTIABLE)
- **Erlang**: 28.0.1
- **Elixir**: 1.18.4-otp-28
- **CUDA**: 12.4
- **cuDNN**: 8.9.4

## Step 1: Create Instance
```bash
gcloud compute instances create sgp4-gpu-dl \
  --zone=us-central1-a \
  --machine-type=g2-standard-4 \
  --accelerator=type=nvidia-l4,count=1 \
  --image-family=pytorch-latest-gpu \
  --image-project=deeplearning-platform-release \
  --boot-disk-size=200GB \
  --maintenance-policy=TERMINATE
```

## Step 2: Install Erlang/Elixir via asdf
```bash
# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc

# Install build dependencies
sudo apt-get update
sudo apt-get install -y build-essential autoconf m4 libncurses-dev libssl-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop

# Install Erlang 28.0.1
asdf plugin add erlang
asdf install erlang 28.0.1
asdf global erlang 28.0.1

# Install Elixir 1.18.4-otp-28
asdf plugin add elixir
asdf install elixir 1.18.4-otp-28
asdf global elixir 1.18.4-otp-28
```

## Step 3: Get SGP4Ex Code
```bash
cd ~
tar -xzf sgp4_ex_lib.tar.gz  # Or git clone your repo
cd sgp4_ex
```

## Step 4: The CRITICAL Fix - Hardcode CUDA Target
**EXLA ignores EXLA_TARGET environment variable!** Must hardcode it:

```bash
# Edit deps/xla/lib/xla.ex to force cuda12
sed -i 's/System.get_env("XLA_TARGET") || infer_xla_target() || "cpu"/"cuda12"/' deps/xla/lib/xla.ex
```

## Step 5: Build Dependencies
```bash
# Get dependencies
mix deps.get

# Force compile with hardcoded cuda12
rm -rf deps/exla/.compile* deps/exla/cache
mix deps.compile xla --force
mix deps.compile exla --force
mix compile
```

This will download and use: `xla_extension-0.8.0-x86_64-linux-gnu-cuda12.tar.gz`

## Step 6: Force GPU Client in Your Code
Add this to the top of any script using GPU:

```elixir
# Force GPU configuration
Application.put_env(:exla, :clients,
  cuda: [platform: :cuda, preallocate: false],
  host: [platform: :host]
)
Application.put_env(:exla, :default_client, :cuda)
Nx.default_backend(EXLA.Backend)
```

## Verification Test
Create `gpu_verify.exs`:
```elixir
Application.put_env(:exla, :clients,
  cuda: [platform: :cuda, preallocate: false],
  host: [platform: :host]
)
Application.put_env(:exla, :default_client, :cuda)
Nx.default_backend(EXLA.Backend)

test = Nx.tensor([1, 2, 3])
IO.inspect(test, label: "Tensor")
```

Run: `mix run gpu_verify.exs`

Should output:
```
Tensor: #Nx.Tensor<
  s32[3]
  EXLA.Backend<cuda:0, ...>
  [1, 2, 3]
>
```

## What DOESN'T Work (Don't Waste Time)
1. **EXLA_TARGET environment variable** - IGNORED by build system
2. **XLA_BUILD=true** - Builds CPU version regardless of EXLA_TARGET
3. **Symlinking CPU to CUDA tarball** - Works initially but causes cuDNN errors
4. **Any timeout on builds** - NEVER set timeouts, builds take 20-30 minutes

## Critical Build Rules
1. **NO TIMEOUTS** - Let builds run to completion
2. **NO FOREGROUND BUILDS** - Use nohup or screen for long builds
3. **ALWAYS VERIFY GPU** - Check for "cuda:0" before benchmarking
4. **NO cuDNN ERRORS ALLOWED** - Per PRIME DIRECTIVE

## Current Snapshot
`sgp4-gpu-working-cuda-hardcoded` - The ONLY working configuration

## Success Criteria Met
- ✅ Runs on GCP GPU instance
- ✅ Shows "cuda:0" in tensor output
- ✅ XLA service initialized for platform CUDA
- ✅ Detects NVIDIA L4, Compute Capability 8.9
- ⚠️  cuDNN status still needs testing with actual computations