[CmdletBinding()]
param(
    [string]$SwiftExecutable = "swift",
    [string]$ScratchRoot,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$ServerArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..")
)
$serverPath = Join-Path $repositoryRoot "server"

if ([string]::IsNullOrWhiteSpace($ScratchRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($env:SLOWWALK_SCRATCH_ROOT)) {
        $ScratchRoot = Join-Path $env:SLOWWALK_SCRATCH_ROOT "server"
    }
    else {
        $ScratchRoot = Join-Path $repositoryRoot ".local\swiftpm\server"
    }
}

$ScratchRoot = [IO.Path]::GetFullPath($ScratchRoot)
$swift = Get-Command $SwiftExecutable -ErrorAction SilentlyContinue
if ($null -eq $swift) {
    Write-Error "Swift command '$SwiftExecutable' was not found. Install a stable Swift 6 toolchain first."
    exit 1
}

if (-not (Test-Path -LiteralPath (Join-Path $serverPath "Package.swift") -PathType Leaf)) {
    Write-Error "Server Package.swift was not found at '$serverPath'."
    exit 1
}

Write-Host "[INFO] Server package: $serverPath"
Write-Host "[INFO] SwiftPM scratch path: $ScratchRoot"
Write-Host "[RUN] SlowWalkServer"

& $swift.Source run `
    --package-path $serverPath `
    --scratch-path $ScratchRoot `
    slow-walk-server `
    @ServerArguments

$serverExitCode = $LASTEXITCODE
if ($serverExitCode -ne 0) {
    Write-Error "SlowWalkServer exited with code $serverExitCode."
    exit $serverExitCode
}
