#Requires -Version 2.0

# Add custom type and format data
split-path $MyInvocation.MyCommand.Path | foreach-object {
    if (($path = join-path $_ profile.types.ps1xml) -and (test-path $path)) { $path | update-typedata }
    if (($path = join-path $_ profile.format.ps1xml) -and (test-path $path)) { $path | update-formatdata }
}

# Aliases
if (test-path alias:\curl) {
    remove-item alias:\curl
}

if (![Environment]::Is64BitProcess) {
    new-alias curl "${env:SystemRoot}\SysNative\curl.exe"
}

if ($PSStyle) {
    $PSStyle.Progress.UseOSCIndicator = $true
    $PSStyle.FileInfo.Directory = "`e[36;1m"
    $PSStyle.FileInfo.SymbolicLink = "`e[34;1;4m"
    $PSStyle.FileInfo.Executable = "`e[32;1;3m"
    $PSStyle.FileInfo.Extension['.exe~'] = "`e[32;2;3m"
    $PSStyle.FileInfo.Extension['.ps1'] = "`e[33;3m"
    $PSStyle.FileInfo.Extension['.psd1'] = "`e[33m"
    $PSStyle.FileInfo.Extension['.psm1'] = "`e[33m"
    $PSStyle.FileInfo.Extension['.ps1xml'] = "`e[33m"
}

# Change the default prompt.
if (Get-Command -Type Application 'o-my-posh' -ErrorAction Ignore) {
    oh-my-posh init pwsh --config ~/.config/oh-my-posh/theme.omp.yml | invoke-expression
} else {
    Write-Host 'Missing "oh-my-posh"; loading fallback prompt...' -ForegroundColor Yellow
    Import-Module MyPrompt
}

# Increase history count.
$global:MaximumHistoryCount = 100

if (!$IsWindows) {
    $env:PSModulePath += ":$PSScriptRoot/Modules"
}

# Chocolatey profile

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Parameter completions

Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# vim: set et sts=4 sw=4 ts=8:
