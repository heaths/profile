#Requires -Version 2.0

# Add custom type and format data
split-path $MyInvocation.MyCommand.Path | foreach-object {
    if (($path = join-path $_ My.types.ps1xml) -and (test-path $path)) { $path | update-typedata }
    if (($path = join-path $_ My.format.ps1xml) -and (test-path $path)) { $path | update-formatdata }
}

# Change the defualt prompt.
function prompt
{
    # Beep K ("over") when a command finishes after the current $BeepPreference.
    if ($BeepPreference -gt 0 -and ($h = get-history -count 1) -and $h.ExecutionTime -gt $BeepPreference) {
        $da817f7daa4f4b8db65c7e8add620143_bt.Start()
    }

    # Show if debugging in the prompt.
    if ($PSDebugContext) {
        &$da817f7daa4f4b8db65c7e8add620143_wp 'DBG' 'Red'
    }

    # Show current location in the prompt.
    write-host $('PS ' + $PWD)

    # Show current repo branch in the prompt.
    if ($repo = &$da817f7daa4f4b8db65c7e8add620143_gb -and $repo.Branch) {
        &$da817f7daa4f4b8db65c7e8add620143_wp $repo.Branch 'Cyan'
    }

    # Show the nesting and default separators in the prompt.
    '+' * $ExecutionContext.SessionState.Path.LocationStack($null).Count + '>' * $NestedPromptLevel + '> '
}

# Hook command lookup.
$ExecutionContext.InvokeCommand.CommandNotFoundAction = {

    $EventArgs = $Args[1]
    $Extensions = @('.bat', '.cmd')

    # Look for local Node.js module commands.
    &$da817f7daa4f4b8db65c7e8add620143_sp {
        if (($gd = join-path $dir 'node_modules\.bin') -and (test-path $gd -pathtype Container)) {
            if ($cmd = $Extensions | &$da817f7daa4f4b8db65c7e8add620143_gcm $gd $EventArgs.CommandName) {
                $EventArgs.Command = $cmd
                $EventArgs.StopSearch = $true
            }
        }
    }

    if ($EventArgs.StopSearch) {
        return
    }

    # Look for global Node.js module commands.
    if (($gd = join-path $env:AppData 'npm\node_modules\bin') -and (test-path $gd -pathtype Container)) {
        if ($out = $Extensions | &$da817f7daa4f4b8db65c7e8add620143_gcm $gd $EventArgs.CommandName) {
            $EventArgs.Command = $cmd
            $EventArgs.StopSearch = $true
        }
    }
}

# Do not beep in the prompt by default.
[timespan] $BeepPreference = 0

# Set up the BeepTimer for async beeps in prompt.
new-object System.Timers.Timer -property @{AutoReset = $false; Interval = 1} `
    | new-variable da817f7daa4f4b8db65c7e8add620143_bt -option Constant -visibility Private
$null = register-objectevent $da817f7daa4f4b8db65c7e8add620143_bt -event Elapsed -supportevent -action {
    300, 100, 300 | foreach { [Console]::Beep(800, $_); start-sleep -m 100 }
}

# Increase history count.
$MaximumHistoryCount = 100

# Private functions

new-variable da817f7daa4f4b8db65c7e8add620143_wp -option Constant -visibility Private -scope Private -value {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        $Token,

        [Parameter(Mandatory=$true, Position=1)]
        [ConsoleColor] $Foreground
    )

    write-host '[' -foreground 'Yellow' -nonewline
    write-host $Token -foreground $Foreground -nonewline
    write-host '] ' -foreground 'Yellow' -nonewline
}

new-variable da817f7daa4f4b8db65c7e8add620143_gb -option Constant -visibility Private -value {

    if ($dir = &$da817f7daa4f4b8db65c7e8add620143_gr) {

        $repo = new-object PSObject -property @{ 'Branch' = $null; 'SCM' = $dir.SCM }

        switch ($dir.SCM) {
            'Git' {
                $branch = if (($path = join-path $dir 'HEAD') -and (test-path $path)) {
                    resolve-path $path | get-content
                }

                if ($branch -match 'ref: refs/heads/(?<b>\w+)') {
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

new-variable da817f7daa4f4b8db65c7e8add620143_gcm -option Constant -visibility Private -value {

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        $Directory,

        [Parameter(Mandatory=$true, Position=1)]
        [string] $Command,

        [Parameter(ValueFromPipeline=$true)]
        [string] $Extension
    )

    process {
        if (($cmd = join-path $Directory ($Command + $Extension)) -and (test-path $cmd)) {
            return $ExecutionContext.InvokeCommand.GetCommand($cmd, 'Application')
        }
    }
}

new-variable da817f7daa4f4b8db65c7e8add620143_gr -option Constant -visibility Private -value {

    if ((test-path env:GIT_DIR) -and (test-path $env:GIT_DIR -pathtype 'Container')) {
        return (resolve-path $env:GIT_DIR | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)
    }

    &$da817f7daa4f4b8db65c7e8add620143_sp {

        if (($gd = join-path $dir '.git') -and (test-path $gd -pathtype 'Container')) {
            # check if git repository
            return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)

        } elseif (test-path $gd -pathtype 'Leaf') {
            # check if git submodule
            if ((resolve-path $gd | get-content) -match 'gitdir: (?<d>.+)') {
                if (($gd = join-path $dir $Matches['d']) -and (test-path $gd -pathtype 'Container')) {
                    return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Git' -passthru)
                }
            }

        } elseif (($gd = join-path $dir '.hg') -and (test-path $gd)) {
            # check if hg repository
            return (resolve-path $gd | add-member -type NoteProperty -name 'SCM' -value 'Hg' -passthru)
        }
    }
}

new-variable da817f7daa4f4b8db65c7e8add620143_sp -option Constant -visibility Private -value {

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

# vim: set et sts=4 sw=4 ts=8:
