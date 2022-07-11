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

# Preferences
[bool] $global:PromptExecutionTimePreference = $true

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
function global:prompt {
    $Profile_Prompt | &$Profile_FormatPrompt
}

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

if (!(test-path variable:\Profile_Prompt)) {
new-variable Profile_Prompt -option Constant -visibility Private -value $(
    # Windows PowerShell does not support $(Profile_Chars.ESC) or `u escape sequences.
    new-variable Profile_Chars -option Constant -visibility Private -value @{
        ESC    = [char]0x1b
        BRANCH = [char]0xe0a0
        SEP    = [char]0xe0b0
        GT     = [char]0xe0b1
    }

    new-variable Profile_Colors -option Constant -visibility Private -value @{
        BLUE        = 31
        DARKGRAY    = 236
        LIGHTGRAY   = 240
        LIGHTERGRAY = 252
        PURPLE      = 55
        RED         = 1
        DARKRED     = 52
        WHITE       = 231
    }

    new-variable Profile_OSC8 -option Constant -visibility Private -value $(
        $env:WT_SESSION -or $env:TERM -like 'xterm*'
    )

    @(
        {if ($PSDebugContext) {'DBG', $Profile_Colors.WHITE, $Profile_Colors.RED}}
        {'PS', $Profile_Colors.WHITE, $Profile_Colors.PURPLE}
        {if ($h = get-history -count 1) {
            (' {0} ' -f $h.Id), $Profile_Colors.WHITE, $Profile_Colors.BLUE
            if ($PromptExecutionTimePreference) {
                (' {0:hh\:mm\:ss\.fff} ' -f $h.ExecutionTime), $Profile_Colors.WHITE, $Profile_Colors.BLUE
            }
            if ($prevhid -ne $h.Id) {
                $script:prevhid = $h.Id
                $script:preverr = 0
            }
        }}
        {if ($global:LASTEXITCODE) {
            $script:preverr = $global:LASTEXITCODE
            $global:LASTEXITCODE = 0
        }
        if ($preverr) {
            " $preverr ", $Profile_Colors.WHITE, $Profile_Colors.DARKRED
        }}
        {if ($Profile_OSC8 -and $PWD.Provider.Name -eq 'FileSystem') {
            $cwd = $PWD.ProviderPath
            if ($env:WSL_DISTRO_NAME) {
                " $($Profile_Chars.ESC)]8;;file://wsl$/${env:WSL_DISTRO_NAME}$cwd$($Profile_Chars.ESC)\$PWD$($Profile_Chars.ESC)]8;;$($Profile_Chars.ESC)\ "
            } else {
                " $($Profile_Chars.ESC)]8;;file://$cwd$($Profile_Chars.ESC)\$PWD$($Profile_Chars.ESC)]8;;$($Profile_Chars.ESC)\ "
            }
        } else {
            " $PWD "
        }, $Profile_Colors.WHITE, $Profile_Colors.LIGHTGRAY}
        {"`n"}
        {if ($repo = &$Profile_GetBranch -and $repo.Branch) {
            [Console]::Title = $repo.Clone
            (" $($Profile_Chars.BRANCH) $($repo.Branch) "), $Profile_Colors.WHITE, $Profile_Colors.DARKGRAY
        } else {
            [Console]::Title = $Profile_OriginalTitle
        }}
        {if ($c = $global:ExecutionContext.SessionState.Path.LocationStack($null).Count) {
            (' ' + '+' * $c), $Profile_Colors.LIGHTERGRAY, $Profile_Colors.LIGHTGRAY
        }}
        {([string]$Profile_Chars.GT * $NestedPromptLevel), $Profile_Colors.LIGHTERGRAY, $Profile_Colors.LIGHTGRAY}
    )
)}

if (!(test-path variable:\Profile_FormatPrompt)) {
new-variable Profile_FormatPrompt -option Constant -visibility Private -value {
    $ESC = $Profile_Chars.ESC
    $SEP = $Profile_Chars.SEP
    $GT  = $Profile_Chars.GT

    $LIGHTGRAY   = $Profile_Colors.LIGHTGRAY
    $LIGHTERGRAY = $Profile_Colors.LIGHTERGRAY
    $RED         = $Profile_Colors.RED

    $END = "$ESC[0;38;5;${LIGHTGRAY}m$SEP$ESC[0m "

    if (!$Profile_PromptInitialized) {
        new-variable Profile_PromptInitialized -scope Global -option Constant -visibility Private -value $true

        $title = if ($IsWindows) { [Console]::Title } else { '' }
        new-variable Profile_OriginalTitle -scope Global -option Constant -visibility Private -value $title

        $m = get-module -FullyQualifiedName @{ModuleName = 'PSReadLine'; ModuleVersion = '2.0.0'}
        $opts = @{}

        if ($m -and (!$m.PrivateData.PSData.Prerelease -or $m.PrivateData.PSData.Prerelease -ge 'rc1')) {
            $opts['ContinuationPrompt'] = "$ESC[0;38;5;252;48;5;240m$GT$GT$ESC[0;38;5;240m$SEP$ESC[0m "
            $opts['PromptText'] = $END, "$ESC[0;38;5;${RED}m$SEP$ESC[0m "
        }

        if ($m.Version -ge '2.1.0') {
            $opts['Colors'] += @{
                InlinePrediction="$ESC[38;5;240m"
            }
            $opts['PredictionSource'] = 'HistoryAndPlugin'
        }

        if ($m.Version -gt '2.1.0') {
            $opts['Colors'] += @{
                ListPredictionSelected = "$ESC[48;5;240m"
            }

            set-psreadlinekeyhandler -Chord 'Ctrl+f' -Function 'ForwardWord'
        }

        set-psreadlineoption @opts
    }

    $script:prevstr, $script:prevfg, $script:prevbg = $null, 0, 0
    $prompt = $Input | foreach-object -process {
        $str, $fg, $bg, $next = $_.Invoke()
        do {
            if (!$str) {
                return
            }

            if ($str -eq "`n") {
                "$ESC[0;38;5;${prevbg}m$SEP$ESC[0m`n"
                $script:prevstr, $script:prevfg, $script:prevbg = $null, 0, $LIGHTGRAY
                return
            } elseif ($prevstr -and $prevbg -ne $bg) {
                "$ESC[0;38;5;${prevbg};48;5;${bg}m$SEP"
            } elseif ($prevstr -and $prevbg -eq $bg -and !$prevstr.EndsWith('+')) {
                "$ESC[38;5;${LIGHTERGRAY}m$GT$ESC[38;5;${prevfg}m"
            }

            "$ESC[0;38;5;$fg;48;5;${bg}m$str"
            $script:prevstr, $script:prevfg, $script:prevbg = $str, $fg, $bg

            $str, $fg, $bg, $next = $next
        } while ($bg)
    } -end {
        if ($prevbg -ne $LIGHTGRAY) {
            "$ESC[0;38;5;${prevbg};48;5;${LIGHTGRAY}m$SEP"
        }

        $END
    }

    -join $prompt
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
