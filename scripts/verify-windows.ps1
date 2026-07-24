[CmdletBinding()]
param(
    [string]$SwiftExecutable = "swift",
    [string]$ScratchRoot,
    [switch]$SkipServer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Result {
    param(
        [Parameter(Mandatory)]
        [string]$Status,
        [Parameter(Mandatory)]
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host "[$Status] $Message" -ForegroundColor $Color
}

function Invoke-SwiftStep {
    param(
        [Parameter(Mandatory)]
        [string]$Label,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    Write-Result -Status "RUN" -Message $Label -Color Cyan
    & $script:SwiftCommand @Arguments
    $stepExitCode = $LASTEXITCODE

    if ($stepExitCode -ne 0) {
        throw "$Label failed with exit code $stepExitCode."
    }

    Write-Result -Status "OK" -Message $Label -Color Green
}

try {
    $repositoryRoot = [IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "..")
    )

    if ([string]::IsNullOrWhiteSpace($ScratchRoot)) {
        if (-not [string]::IsNullOrWhiteSpace($env:SLOWWALK_SCRATCH_ROOT)) {
            $ScratchRoot = $env:SLOWWALK_SCRATCH_ROOT
        }
        else {
            $ScratchRoot = Join-Path $repositoryRoot ".local\swiftpm"
        }
    }

    $ScratchRoot = [IO.Path]::GetFullPath($ScratchRoot)
    $swift = Get-Command $SwiftExecutable -ErrorAction SilentlyContinue
    if ($null -eq $swift) {
        throw "Swift command '$SwiftExecutable' was not found. Install a stable Swift 6 toolchain first."
    }

    $script:SwiftCommand = $swift.Source
    Write-Result -Status "INFO" -Message "Repository: $repositoryRoot"
    Write-Result -Status "INFO" -Message "SwiftPM scratch root: $ScratchRoot"

    Invoke-SwiftStep -Label "Check Swift toolchain" -Arguments @("--version")

    $corePath = Join-Path $repositoryRoot "swift-packages\SlowWalkCore"
    if (-not (Test-Path -LiteralPath (Join-Path $corePath "Package.swift") -PathType Leaf)) {
        throw "Core Package.swift was not found at '$corePath'."
    }

    $coreScratch = Join-Path $ScratchRoot "core"
    Invoke-SwiftStep -Label "Resolve SlowWalkCore" -Arguments @(
        "package", "--package-path", $corePath, "--scratch-path", $coreScratch, "resolve"
    )
    Invoke-SwiftStep -Label "Build SlowWalkCore" -Arguments @(
        "build", "--package-path", $corePath, "--scratch-path", $coreScratch
    )
    Invoke-SwiftStep -Label "Test SlowWalkCore" -Arguments @(
        "test", "--package-path", $corePath, "--scratch-path", $coreScratch
    )

    if ($SkipServer) {
        Write-Result -Status "SKIP" -Message "Server verification was explicitly skipped." -Color Yellow
    }
    else {
        $serverPath = Join-Path $repositoryRoot "server"
        if (-not (Test-Path -LiteralPath (Join-Path $serverPath "Package.swift") -PathType Leaf)) {
            throw "Server Package.swift was not found at '$serverPath'."
        }

        $serverScratch = Join-Path $ScratchRoot "server"
        Invoke-SwiftStep -Label "Resolve SlowWalkServer" -Arguments @(
            "package", "--package-path", $serverPath, "--scratch-path", $serverScratch, "resolve"
        )
        Invoke-SwiftStep -Label "Build SlowWalkServer" -Arguments @(
            "build", "--package-path", $serverPath, "--scratch-path", $serverScratch
        )
        Invoke-SwiftStep -Label "Test SlowWalkServer" -Arguments @(
            "test", "--package-path", $serverPath, "--scratch-path", $serverScratch
        )
    }

    Write-Result -Status "PASS" -Message "All requested verification steps passed." -Color Green
    exit 0
}
catch {
    Write-Result -Status "FAIL" -Message $_.Exception.Message -Color Red
    exit 1
}

