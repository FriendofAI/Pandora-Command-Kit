Write-Host "[GitHub Installer] Started..." -ForegroundColor Green

# Popular repositories
$repoOptions = @(
    @{ Name = "AUTOMATIC1111/stable-diffusion-webui"; Url = "https://github.com/AUTOMATIC1111/stable-diffusion-webui.git" },
    @{ Name = "comfyanonymous/ComfyUI"; Url = "https://github.com/comfyanonymous/ComfyUI.git" },
    @{ Name = "lllyasviel/stable-diffusion-webui-forge"; Url = "https://github.com/lllyasviel/stable-diffusion-webui-forge.git" },
    @{ Name = "lllyasviel/FramePack"; Url = "https://github.com/lllyasviel/FramePack.git" }
)

Write-Host "Select a repository to install or enter your own:"
for ($i = 0; $i -lt $repoOptions.Count; $i++) {
    Write-Host ("  [{0}] {1}" -f ($i+1), $repoOptions[$i].Name)
}
Write-Host "  [5] Enter a custom GitHub URL"

$repoChoice = Read-Host "Enter your choice (1-5)"

switch ($repoChoice) {
    1 { $repoUrl = $repoOptions[0].Url }
    2 { $repoUrl = $repoOptions[1].Url }
    3 { $repoUrl = $repoOptions[2].Url }
    4 { $repoUrl = $repoOptions[3].Url }
    5 { $repoUrl = Read-Host "Enter the GitHub repository URL" }
    default {
        Write-Host "Invalid selection. Exiting."
        return
    }
}

if (-not $repoUrl) {
    Write-Host "No URL entered. Exiting."
    return
}

# Prompt for destination folder
$defaultDest = Join-Path $PSScriptRoot "ClonedRepos"
if (!(Test-Path $defaultDest)) { New-Item -ItemType Directory -Path $defaultDest | Out-Null }
$destFolder = Read-Host "Enter destination folder (or press Enter for default: $defaultDest)"
if (-not $destFolder) { $destFolder = $defaultDest }

# Extract repo name
$repoName = ($repoUrl -split '/')[-1] -replace '\.git$',''
$targetPath = Join-Path $destFolder $repoName

# Clone repo
Write-Host "Cloning $repoUrl to $targetPath..."
if (Test-Path $targetPath) {
    Write-Host "Target folder already exists. Remove or choose another destination." -ForegroundColor Yellow
    return
}
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host "Git is not installed or not in PATH. Please install Git first." -ForegroundColor Red
    return
}
git clone $repoUrl $targetPath
if (!(Test-Path $targetPath)) {
    Write-Host "Clone failed. Exiting." -ForegroundColor Red
    return
}
Write-Host "Clone successful!"

# Detect environment files
$reqFile = Join-Path $targetPath 'requirements.txt'
$envFile = Join-Path $targetPath 'environment.yml'
$hasReq = Test-Path $reqFile
$hasEnv = Test-Path $envFile

# Detect conda
$conda = Get-Command conda -ErrorAction SilentlyContinue

# Decision logic
if ($hasReq -and -not $hasEnv) {
    Write-Host "requirements.txt found. Using venv + pip install."
    $venvPath = Join-Path $targetPath 'venv'
    python -m venv $venvPath
    & "$venvPath\Scripts\activate.ps1"
    python -m pip install --upgrade pip
    pip install -r $reqFile
    Write-Host "Dependencies installed in venv."
} elseif ($hasEnv -and $conda -and -not $hasReq) {
    Write-Host "environment.yml found. Conda detected. Using conda env create."
    conda env create -f $envFile
    Write-Host "Conda environment created. Activate with: conda activate $repoName"
} elseif ($hasReq -and $hasEnv -and $conda) {
    Write-Host "Both requirements.txt and environment.yml found."
    $choice = Read-Host "Type 1 for venv+pip, 2 for conda env create (default: 1)"
    if ($choice -eq '2') {
        conda env create -f $envFile
        Write-Host "Conda environment created. Activate with: conda activate $repoName"
    } else {
        $venvPath = Join-Path $targetPath 'venv'
        python -m venv $venvPath
        & "$venvPath\Scripts\activate.ps1"
        python -m pip install --upgrade pip
        pip install -r $reqFile
        Write-Host "Dependencies installed in venv."
    }
} else {
    Write-Host "No requirements.txt or environment.yml found. Repo cloned only."
}

Write-Host "[GitHub Installer] Complete." 

# --- CUDA/GPU Post-Install Check and Fix ---

# Detect GPU (reuse logic from Curiosity)
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 Name
$gpuName = $gpu.Name

# Only proceed if a known NVIDIA GPU is detected
if ($gpuName -match "NVIDIA" -or $gpuName -match "RTX" -or $gpuName -match "4090" -or $gpuName -match "3090" -or $gpuName -match "A6000") {
    Write-Host "\n[GPU Check] Detected GPU: $gpuName" -ForegroundColor Cyan
    # Try running a simple CUDA test in the venv
    $venvPython = Join-Path $targetPath 'venv\Scripts\python.exe'
    if (Test-Path $venvPython) {
        $cudaTest = "import torch; print(torch.cuda.is_available())"
        $cudaResult = & $venvPython -c $cudaTest
        if ($cudaResult -eq 'True') {
            Write-Host "CUDA is working! Your GPU will be used." -ForegroundColor Green
        } else {
            Write-Host "CUDA is NOT working with your GPU ($gpuName)." -ForegroundColor Yellow
            # Recommend fix based on Python version and GPU
            $pyVer = & $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
            $recommend = "Reinstall torch/torchvision for your CUDA version."
            $torchLink = "https://pytorch.org/get-started/locally/"
            $nvidiaLink = "https://www.nvidia.com/Download/index.aspx"
            Write-Host "Recommendation: $recommend" -ForegroundColor Cyan
            Write-Host "PyTorch install guide: $torchLink"
            Write-Host "NVIDIA driver download: $nvidiaLink"
            $userFix = Read-Host "Would you like Pandora to attempt to reinstall torch/torchvision for CUDA automatically? (Y/N)"
            if ($userFix -eq 'Y' -or $userFix -eq 'y') {
                # Try to detect CUDA version (robust)
                $cudaFolder = (Get-ChildItem 'C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1).Name
                if ($cudaFolder -match '^v(\d+)\.(\d+)$') {
                    $cudaVer = 'cu' + $Matches[1] + $Matches[2]
                } else {
                    $cudaVer = 'cu121' # Default to CUDA 12.1 if unknown
                }
                # Warn if no NVIDIA driver found
                $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
                if (-not $nvidiaSmi) {
                    Write-Host "[Warning] NVIDIA driver not found. Please install the latest driver: https://www.nvidia.com/Download/index.aspx" -ForegroundColor Yellow
                }
                # Warn if Python version is unsupported
                $pyVer = & $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
                if ($pyVer -notmatch '3.10|3.11') {
                    Write-Host "[Warning] Detected Python $pyVer. PyTorch may not support this version. See: https://pytorch.org/get-started/locally/" -ForegroundColor Yellow
                }
                $pipArgs = @('install', 'torch', 'torchvision', '--index-url', "https://download.pytorch.org/whl/$cudaVer")
                Write-Host "Running: $venvPython -m pip $($pipArgs -join ' ')"
                try {
                    & $venvPython -m pip @pipArgs
                    Write-Host "torch/torchvision reinstalled. Please try running the app again."
                } catch {
                    Write-Host "[Error] pip install failed. Please try manually:"
                    Write-Host "$venvPython -m pip $($pipArgs -join ' ')"
                    Write-Host "See PyTorch install guide: https://pytorch.org/get-started/locally/"
                }
            } else {
                $cpuFallback = Read-Host "Would you like to run in CPU mode instead? (This will add --skip-torch-cuda-test to your launch command) (Y/N)"
                if ($cpuFallback -eq 'Y' -or $cpuFallback -eq 'y') {
                    # Try to patch start.bat or webui-user.bat
                    $startBat = Join-Path $targetPath 'start.bat'
                    if (Test-Path $startBat) {
                        (Get-Content $startBat) | ForEach-Object {
                            if ($_ -match 'python ' -and $_ -notmatch '--skip-torch-cuda-test') {
                                $_ += ' --skip-torch-cuda-test'
                            }
                            $_
                        } | Set-Content $startBat
                        Write-Host "--skip-torch-cuda-test added to start.bat."
                    } else {
                        Write-Host "Please add --skip-torch-cuda-test to your launch command manually."
                    }
                } else {
                    Write-Host "No changes made. Please consult the links above for manual troubleshooting." -ForegroundColor Yellow
                }
            }
        }
    }
} 