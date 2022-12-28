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
oh-my-posh init pwsh --config ~/.config/oh-my-posh/theme.omp.yml | invoke-expression

# Increase history count.
$global:MaximumHistoryCount = 100

if (!$IsWindows) {
    $env:PSModulePath += ":$PSScriptRoot/Modules"
}

# Private functions

if (!(test-path variable:\Profile_GetBranch)) {
new-variable Profile_GetBranch -option Constant -visibility Private -value {

    if ($dir = &$Profile_GetRepo) {

        $repo = new-object PSObject -property @{
            Branch = $null
            Clone = $dir.Clone
            SCM = $dir.SCM
        }

        switch ($dir.SCM) {
            'Git' {
                $branch = if (($path = join-path $dir 'HEAD') -and (test-path $path)) {
                    resolve-path $path | get-content
                }

                if ($branch -match 'ref: refs/heads/(?<b>[\w_\.\-/]+)') {
                    $branch = $Matches['b']

                } elseif ($branch.length -ge 7) {
                    $branch = 'hash: ' + $branch.Substring(0, 7)

                }

                $repo.Branch = $branch
            }

            'Hg' {
                $branch = if (($path = join-path $dir 'branch') -and (test-path $path)) {
                    resolve-path $path | get-content
                }

                $repo.Branch = $branch
            }
        }

        $repo
    }
}}

if (!(test-path variable:\Profile_GetRepo)) {
new-variable Profile_GetRepo -option Constant -visibility Private -value {

    if ((test-path env:GIT_DIR) -and (test-path $env:GIT_DIR -pathtype 'Container')) {
        return (resolve-path $env:GIT_DIR | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)
    }

    &$Profile_SearchParent {

        if (($gd = join-path $dir '.git') -and (test-path $gd)) {
            if (test-path $gd -pathtype 'Container') {
                # git repository
                return (resolve-path $gd `
                    | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru `
                    | add-member -type NoteProperty -name 'Clone' -value (join-path $gd .. -resolve | split-path -leaf) -passthru)

            } elseif (test-path $gd -pathtype 'Leaf') {
                # git submodule or worktree
                if ((resolve-path $gd | get-content) -match 'gitdir: (?<d>.+)') {
                    # join-path simply concatenates both paths so use path.combine if gitdir is absolute
                    if (($gd = [io.path]::combine($dir, $Matches['d'])) -and (test-path $gd -pathtype 'Container')) {
                        return (resolve-path $gd `
                            | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru `
                            | add-member -type NoteProperty -name 'Clone' -value ($gd | split-path -leaf) -passthru)
                    }
                }
            }

        } elseif (($gd = join-path $dir '.hg') -and (test-path $gd)) {
            # check if hg repository
            return (resolve-path $gd `
                | add-member -type NoteProperty -name 'SCM' -value 'Hg' -passthru `
                | add-member -type NoteProperty -name 'Clone' -value (join-path $gd .. -resolve | split-path -leaf) -passthru)
        }
    }
}}

if (!(test-path variable:\Profile_SearchParent)) {
new-variable Profile_SearchParent -option Constant -visibility Private -value {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [scriptblock] $Filter
    )

    $dir = resolve-path .

    while ($dir) {

        # pass the path to the filter script
        if ($out = &$Filter $dir) {
            return $out
        }

        $dir = if (($parent = split-path $dir -parent) -and (test-path $parent)) {
            resolve-path $parent
        }
    }
}}

# Useful variables.

if (!(test-path variable:\Git)) {
new-object PSObject | `
    add-member -name Branch -type ScriptProperty -value { (&$Profile_GetBranch).Branch } -passthru | `
    add-member -name Clone -type ScriptProperty -value { (&$Profile_GetRepo).Clone } -passthru | `
    add-member -name Root -type ScriptProperty -value { (&$Profile_GetRepo).Path } -passthru | `
    new-variable -name Git -option Constant -scope Global
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
