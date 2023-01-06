#Requires -Version 2.0

# Preference variables.
new-variable PromptExecutionTimePreference -value $true -scope Global -force

# Back up current prompt and restore when module unloaded.
new-variable OriginalPrompt -value ${function:prompt} -scope Script -option Constant -visibility Private
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    $function:prompt = $OriginalPrompt
}

# Private module functions.
function global:prompt {
    $Segments | Format-Prompt
}

function Get-Branch {
    if ($dir = Get-Repo) {

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
}

function Get-Repo {
    if ((test-path env:GIT_DIR) -and (test-path $env:GIT_DIR -pathtype 'Container')) {
        return (resolve-path $env:GIT_DIR | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)
    }

    Search-Parent {

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
}

function Search-Parent {
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
}

# Windows PowerShell does not support $(Chars.ESC) or `u escape sequences.
new-variable Chars -option Constant -visibility Private -value @{
    ESC    = [char]0x1b
    BRANCH = [char]0xe0a0
    SEP    = [char]0xe0b0
    GT     = [char]0xe0b1
}

new-variable Colors -option Constant -visibility Private -value @{
    BLUE        = 31
    DARKGRAY    = 236
    LIGHTGRAY   = 240
    LIGHTERGRAY = 252
    PURPLE      = 55
    RED         = 1
    DARKRED     = 52
    WHITE       = 231
}

new-variable SupportsOSC8 -option Constant -visibility Private -value $(
    $env:WT_SESSION -or $env:TERM -like 'xterm*'
)

new-variable Segments -option Constant -visibility Public -value @(
    {if ($PSDebugContext) {'DBG', $Colors.WHITE, $Colors.RED}}
    {'PS', $Colors.WHITE, $Colors.PURPLE}
    {if ($h = get-history -count 1) {
        (' {0} ' -f $h.Id), $Colors.WHITE, $Colors.BLUE
        if ($PromptExecutionTimePreference) {
            (' {0:hh\:mm\:ss\.fff} ' -f $h.ExecutionTime), $Colors.WHITE, $Colors.BLUE
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
        " $preverr ", $Colors.WHITE, $Colors.DARKRED
    }}
    {if ($SupportsOSC8 -and $PWD.Provider.Name -eq 'FileSystem') {
        $cwd = $PWD.ProviderPath
        if ($env:WSL_DISTRO_NAME) {
            " $($Chars.ESC)]8;;file://wsl$/${env:WSL_DISTRO_NAME}$cwd$($Chars.ESC)\$PWD$($Chars.ESC)]8;;$($Chars.ESC)\ "
        } else {
            " $($Chars.ESC)]8;;file://$cwd$($Chars.ESC)\$PWD$($Chars.ESC)]8;;$($Chars.ESC)\ "
        }
    } else {
        " $PWD "
    }, $Colors.WHITE, $Colors.LIGHTGRAY}
    {"`n"}
    {if ($repo = Get-Branch -and $repo.Branch) {
        [Console]::Title = $repo.Clone
        (" $($Chars.BRANCH) $($repo.Branch) "), $Colors.WHITE, $Colors.DARKGRAY
    } else {
        [Console]::Title = $OriginalTitle
    }}
    {if ($c = $global:ExecutionContext.SessionState.Path.LocationStack($null).Count) {
        (' ' + '+' * $c), $Colors.LIGHTERGRAY, $Colors.LIGHTGRAY
    }}
    {([string]$Chars.GT * $NestedPromptLevel), $Colors.LIGHTERGRAY, $Colors.LIGHTGRAY}
)

function Format-Prompt {
    $ESC = $Chars.ESC
    $SEP = $Chars.SEP
    $GT  = $Chars.GT

    $LIGHTGRAY   = $Colors.LIGHTGRAY
    $LIGHTERGRAY = $Colors.LIGHTERGRAY
    $RED         = $Colors.RED

    $END = "$ESC[0;38;5;${LIGHTGRAY}m$SEP$ESC[0m "

    if (!$PromptInitialized) {
        new-variable PromptInitialized -scope Script -option Constant -visibility Private -value $true

        $title = if ($IsWindows) { [Console]::Title } else { '' }
        new-variable OriginalTitle -scope Script -option Constant -visibility Private -value $title

        $m = get-module -FullyQualifiedName @{ModuleName = 'PSReadLine'; ModuleVersion = '2.0.0'}
        $opts = @{}

        if ($m -and (!$m.PrivateData.PSData.Prerelease -or $m.PrivateData.PSData.Prerelease -ge 'rc1')) {
            $opts['ContinuationPrompt'] = "$ESC[0;38;5;252;48;5;240m$GT$GT$ESC[0;38;5;240m$SEP$ESC[0m "
            $opts['PromptText'] = $END, "$ESC[0;38;5;${RED}m$SEP$ESC[0m "
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
}
